require "kemal"
require "json"
require "logger"

# TODO: Write documentation for `MedRTCSignal`

module MedRTCSignal
  VERSION = "0.1.0"

  class SignalServer
    getter log
    getter sockets

    def initialize
      @log = Logger.new(STDOUT)
      @log.level = Logger::DEBUG
      @sockets = SocketDictionary.new
    end

    def start
      ws "/test" do |socket|
        # Remove the socket from the room if the connection is lost.
        socket.on_close do
          @log.debug("Closing socket.")
          @sockets.remove_user_with_socket socket
        end

        socket.on_message do |m|
          # Cast JSON to Hash
          begin
            message = JSON.parse(m).as_h
          rescue
            # This tends to be when `null` is received from the client. Try not to send bullshit from the client though.
            socket.send({error: "\"#{m}\" is not a valid message."}.to_json)
            next
          end

          # We need the room id in order to associate any given message with a specific call.
          room_id = (message.has_key? "roomId") ? message["roomId"].to_s : nil

          unless room_id && room_id != ""
            socket.send({error: "\"roomId\" is required."}.to_json)
            next
          end

          # We need the userId to persist connections between two specific clients.
          user_id = (message.has_key? "userId") ? message["userId"].to_s : nil

          unless user_id && user_id != ""
            socket.send({error: "\"userId\" is required."}.to_json)
            next
          end

          # We only ever allow 2 users per room.
          room_occupant_user_ids = @sockets[room_id].keys.select { |room_user_id| room_user_id != user_id }
          if room_occupant_user_ids.size > 1
            socket.send({error: "Room is already fully occupied."}.to_json)
            next
          end

          # Ensure the @sockets hash has this room set with an up-to-date socket for this user.
          # Will "create the room" if it doesn't exist
          # Will always keep this user_id's socket up-to-date with each message received by it.
          @sockets[room_id][user_id] = socket

          # Get the other user's socket if it exists ELSE update the current user that they're alone :(
          other_user_socket = uninitialized HTTP::WebSocket

          @log.debug("Connected #{user_id} to room #{room_id}")
          
          if room_occupant_user_ids.size != 0
            other_user_socket = @sockets[room_id][room_occupant_user_ids[0]]
          else
            socket.send({info: "You are the only caller connected. Please wait for the other caller to join."}.to_json)
            next # Moving along since there is nobody to send messages to.
          end
          

          # # Handle the message.
          @log.debug(message.inspect)
          candidate = (message.has_key? "candidate") ? message["candidate"] : nil
          desc = (message.has_key? "desc") ? message["desc"].as_h : nil

          if desc
            @log.debug(desc["type"])
            @log.debug({desc: desc}.to_json)
            other_user_socket.send({desc: desc}.to_json)
          elsif candidate
            @log.debug({candidate: candidate}.to_json)
            other_user_socket.send({candidate: candidate}.to_json)
          else
            socket.send({info: "Ready to connect."}.to_json)
            other_user_socket.send({info: "Ready to connect."}.to_json)
            next
          end

        end
      end
      Kemal.run
    end
  end

    class SocketDictionary
      getter rooms
  
      def initialize
        @log = Logger.new(STDOUT)
        @log.level = Logger::DEBUG
        @rooms = {} of String => RoomDictionary
      end
  
      def [](room_id : String)
        begin
          room = @rooms[room_id]
          return room
        rescue Exception
          new_room = RoomDictionary.new
          @rooms[room_id] = new_room
          return new_room
        end
      end
  
      def []=(room_id : String, room_dict : RoomDictionary)
        @log.debug("Adding room_id key #{room_id} with value of #{room_dict.keys}")
        @rooms[room_id] = room_dict
      end

      def remove_user_with_socket(target_socket)
        @rooms.each do |room_id, room|
          @log.debug("Has socket? #{room.has_socket?(target_socket)}")
          room.has_socket?(target_socket) ? room.delete_by_socket(target_socket) : next
          @log.debug("Still has socket? #{room.has_socket?(target_socket)}")
        end
      end
    end
  
  class RoomDictionary
    def initialize
      @room = {} of String => HTTP::WebSocket
    end
  
    def [](user_id)
      @room[user_id]
    end
  
    def []=(user_id : String, socket : HTTP::WebSocket)
      @room[user_id] = socket
    end
  
    def keys
      @room.keys
    end
  
    def delete_by_socket(target_socket : HTTP::WebSocket) 
      @room.each do |user_id, socket|
        (target_socket == socket) ? @room.delete(user_id) : next
      end
    end

    # Iterate each member in the room to see if the socket given is in the room.
    def has_socket?(target_socket : HTTP::WebSocket)
      has_socket = false
      @room.each do |user_id, socket|
        has_socket = (socket == target_socket)
      end
      return has_socket
    end
  end
end

server = MedRTCSignal::SignalServer.new
server.start
