require "crymq"
require "socket"

require "./options"

enum MqttState
  Disconnected
  Handshake
  Connected
end

class MqttClient
  @mutex = Mutex.new
  @state = MqttState::Disconnected
  @initial_connect = true
  @await_pingresp = false
  @last_flush = Time.now
  @pkid: Pkid = Pkid.new(0_u16)
  @socket: TCPSocket
  @opts: MqttOptions

  # queues
  @outgoing_pub = [] of Publish

  def initialize(@opts)
    @socket = TCPSocket.new(@opts.address, @opts.port)
  end

  def connect
    connect = Connect.new(@opts.client_id, @opts.keep_alive)
    @socket.write_bytes(connect, IO::ByteFormat::NetworkEndian)
  end

  def publish(topic : String, qos : QoS, payload : Bytes)
    #TODO: Error for topics with wildcards
    next_pkid
    publish = Publish.new(topic, qos, payload, @pkid)

    @mutex.synchronize do
      case qos
      when QoS::AtleastOnce
        @outgoing_pub << publish
      end
    end

    @socket.write_bytes(publish, IO::ByteFormat::NetworkEndian)
  end

  def subscribe(topics : Array({String, QoS}))
    next_pkid
    subscribe = Subscribe.new(topics, @pkid)
    @socket.write_bytes(subscribe, IO::ByteFormat::NetworkEndian)
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
      when Puback
        pkid = packet.pkid
        @mutex.synchronize do
          index = @outgoing_pub.index {|v| v.pkid == pkid}
          @outgoing_pub.delete_at(index) if index
        end
      when Publish
        payload = packet.payload
        qos = packet.qos
        pkid = packet.pkid
        puts payload

        case qos
        when QoS::AtleastOnce
          puback = Puback.new(pkid)
          @socket.write_bytes(puback, IO::ByteFormat::NetworkEndian)
        end
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

client.subscribe([{"hello/world", QoS::AtleastOnce}])
spawn do
  client.listen
end

5.times do |i|
  client.publish("hello/world", QoS::AtleastOnce, "hello world".to_slice)
  sleep 5
end