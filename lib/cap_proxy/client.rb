require "eventmachine"
require "http/parser"
require_relative "remote_connection"
require_relative "http_codes"

module CapProxy
  class Client < EM::Connection
    attr_reader :server, :head

    def initialize(server)
      @server = server
      @remote = nil
      @data = nil
      @http_parser = HTTP::Parser.new

      @http_parser.on_headers_complete = proc do
        verify_headers!
      end
    end

    def unbind
      if @remote
        @remote.close_connection_after_writing
      end
    end

    def write_head(status, headers)
      head = [ "HTTP/1.1 #{status} #{HTTPCodes[status]}\r\n" ]

      if headers
        headers.each_pair do |key, value|
          head << "#{key}: #{value}\r\n"
        end
      end

      head << "\r\n"
      send_data head.join
    end

    def respond(status, headers, body = nil)
      write_head(status, headers)
      send_data(body) if body
      close_connection_after_writing
    end

    def verify_headers!
      parser = @http_parser
      filter = server.filters.find {|f| f[:filter].apply?(parser) }

      server.log.info "#{parser.http_method} #{parser.request_url} - #{filter ? "filtered" : "raw"}" if server.log
      if filter
        filter[:handler].call self, parser
      else
        @remote = EM.connect(server.target_host, server.target_port, RemoteConnection, self)
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

    def chunks_start(status, headers = {})
      write_head(status, headers.merge("Transfer-Encoding" => "chunked"))
    end

    def chunks_send(data)
      send_data "#{data.bytesize.to_s(16)}\r\n"
      send_data data
      send_data "\r\n"
    end

    def chunks_finish
      send_data "0\r\n\r\n"
      close_connection_after_writing
    end

  end
end
