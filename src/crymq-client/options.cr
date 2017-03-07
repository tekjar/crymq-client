class MqttOptions
  @client_id: String
  property address = "localhost"
  property port = 1883
  @keep_alive: UInt16
  @clean_session: Bool
  @username: String = ""
  @password: String = ""
  @reconnect: UInt8

  def initialize(@client_id, @keep_alive=10_u16, @clean_session=true, @reconnect=10_u8)
  end

  def set_broker(@address, @port = 1883)
    self
  end

  def set_auth(@username, @password)
    self
  end
end