require "crymq"
require "socket"

require "./options"

enum MqttState
  Disconnected
  Handshake
  Connected
end

class MqttClient
  @state = MqttState::Disconnected
  @initial_connect = true
  @await_pingresp = false
  @last_flush = Time.now
  @pkid: Pkid = Pkid.new(1_u16)
  @socket: TCPSocket
  @opts: MqttOptions

  def initialize(@opts)
    @socket = TCPSocket.new(@opts.address, @opts.port)
  end

  def connect
    connect = Connect.new("test_id", 10_u16)
    @socket.write_bytes(connect, IO::ByteFormat::NetworkEndian)
  end
end

opts = MqttOptions.new("test-id").set_broker("localhost")
client = MqttClient.new(opts)
client.connect
sleep 10