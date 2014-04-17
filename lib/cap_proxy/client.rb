require "eventmachine"
require "http_parser"
require "thin"
require_relative "./remote_connection"

module CapProxy
  class Client < EM::Connection
    attr_reader :server, :head

    def initialize(server)
      @server = server
      @remote = nil
      @data = nil
      @http_parser = HTTP::RequestParser.new

      @http_parser.on_headers_complete = proc do
        verify_headers!
      end
    end

    def unbind
      if @remote
        @remote.close_connection_after_writing
      end
    end

    def respond(status, headers, body)
      resp = Thin::Response.new
      resp.status = status
      resp.headers = headers
      resp.body = body
      resp.each do |chunk|
        send_data chunk
      end
      close_connection_after_writing
    end

    def verify_headers!
      parser = @http_parser
      filter = server.filters.find {|f| f[:filter].apply?(parser) }

      server.log.info "#{parser.http_method} #{parser.request_url} - #{filter ? "filtered" : "raw"}"
      if filter
        filter[:handler].call self, parser
      else
        @remote = EM.connect(server.target.hostname, server.target.port, RemoteConnection, self)
        @remote.send_data @data
        @data = nil
        @http_parser = nil
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
        @http_parser << data
      end
    end

  end
end
