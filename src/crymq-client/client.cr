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
  @pkid: Pkid = Pkid.new(0_u16)
  @socket: TCPSocket
  @opts: MqttOptions

  def initialize(@opts)
    @socket = TCPSocket.new(@opts.address, @opts.port)
  end

  def connect
    connect = Connect.new(@opts.client_id, @opts.keep_alive)
    @socket.write_bytes(connect, IO::ByteFormat::NetworkEndian)
  end

  def publish(topic : String, qos : QoS, payload : Bytes)
    next_pkid
    publish = Publish.new(topic, qos, payload, @pkid)
    @socket.write_bytes(publish, IO::ByteFormat::NetworkEndian)
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

  def next_pkid
    if @pkid == 65535
      @pkid.reset
    end
    @pkid.next
  end
end

opts = MqttOptions.new("test-id").set_broker("localhost")
client = MqttClient.new(opts)
client.connect

spawn do
  client.listen
end

loop do
  client.publish("Hello world", QoS::AtleastOnce, "hello world".to_slice)
  sleep 0.5
end