require "./spec_helper"

describe MedRTCSignal do
  describe MedRTCSignal::SignalServer do
    describe "#initialize" do
      it "creates a new SocketDictionary in instance variable @sockets" do
        server = MedRTCSignal::SignalServer.new
        typeof(server.sockets).should eq(MedRTCSignal::SocketDictionary)
      end
    end

    describe "#start" do
    # No means for testing websockets...
    end
  end

  describe MedRTCSignal::SocketDictionary do
    describe "#initialize" do
      it "creates an empty hash of String > MetRTCSignal::RoomDictionary" do
        socket_dictionary = MedRTCSignal::SocketDictionary.new
        typeof(socket_dictionary.rooms).should eq(Hash(String, MedRTCSignal::RoomDictionary))
      end
    end

    describe "#[](room_id : String)" do
      context "when the room_id exists" do
        it "returns the RoomDictionary associated to the given room_id" do
          socket_dictionary = MedRTCSignal::SocketDictionary.new
          room = MedRTCSignal::RoomDictionary.new
          room["user_1"] = HTTP::WebSocket.new("http://localhost")
          socket_dictionary["room_1"] = room
          socket_dictionary["room_1"].should eq(room["user_1"])
        end
      end
    end
  end
end
