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
    connect = Connect.new(@opts.client_id, @opts.keep_alive)
    @socket.write_bytes(connect, IO::ByteFormat::NetworkEndian)
  end

  def listen
    spawn do
      loop do
        ping = Pingreq.new
        @socket.write_bytes(ping, IO::ByteFormat::NetworkEndian)
        sleep @opts.keep_alive * 0.9
      end
    end

    loop do
      packet = @socket.read_bytes(Mqtt, IO::ByteFormat::NetworkEndian)

      case packet
      when Connack
        puts packet
      else
        puts "Misc packet: ", packet.class
      end
    end
  end
end

opts = MqttOptions.new("test-id").set_broker("localhost")
client = MqttClient.new(opts)
client.connect
client.listen