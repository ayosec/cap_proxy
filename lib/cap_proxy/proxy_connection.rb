require "eventmachine"
require_relative "./remote_connection"

class ProxyConnection < EM::Connection
  attr_reader :handler, :head

  def initialize(handler)
    @handler = handler
    @remote = nil
    @data = nil
    @head
  end

  def unbind
    if @remote
      @remote.close_connection_after_writing
    end
  end

  def receive_data(data)
    if @remote
      @remote.send_data data
    else
      if @data
        @data << data
      else
        @data = data
      end

      if pos = @data.index("\r\n")
        @head = @data[0, pos]

        handler.log.info @head
        handler.log.debug "Connect to #{handler.target.hostname}:#{handler.target.port}"

        @remote = EM.connect(handler.target.hostname, handler.target.port, RemoteConnection, self)
        @remote.send_data @data
        @data = nil
      end
    end

  end
end

