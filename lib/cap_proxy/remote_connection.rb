require "eventmachine"

module CapProxy
  class RemoteConnection < EM::Connection
    attr_reader :proxy_connection

    def initialize(proxy_connection)
      @proxy_connection = proxy_connection
    end

    def receive_data(data)
      proxy_connection.handler.log.debug("Closing #{proxy_connection.head}")
      proxy_connection.send_data data
    end

    def unbind
      proxy_connection.close_connection_after_writing
    end
  end
end
