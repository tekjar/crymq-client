class MqttOptions
  property client_id : String
  property address = "localhost"
  property port  = 1883
  property keep_alive : UInt16
  property clean_session : Bool
  property username = ""
  property password = ""
  property reconnect = 10

  def initialize(@client_id, @keep_alive=10_u16, @clean_session=true)
  end

  def set_broker(@address, @port = 1883)
    self
  end

  def set_auth(@username, @password)
    self
  end
end