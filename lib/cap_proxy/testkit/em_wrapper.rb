require "eventmachine"
require "uri"
require "logger"

module CapProxy

  module TestWrapper

    class SimpeResponder < EM::Connection
      def receive_data(_)
        send_data "TCPServer\n"
        close_connection_after_writing
      end
    end

    def self.run(test, proxy_host, proxy_port, target_url)

      if target_url.kind_of?(String)
        target_url = URI.parse(target_url)
      end

      EM.run do

        proxy = nil

        EM.error_handler do |error|
          STDERR.puts error
          STDERR.puts error.backtrace.map {|l| "\t#{l}" }
        end

        if target_url.kind_of?(Hash) and target_url[:simple_responder]
          port = target_url[:simple_responder]
          target_url = "http://localhost:#{port}"
          EM.start_server "localhost", port, SimpeResponder
        end

        logger = Logger.new(STDERR)
        logger.level = Logger::ERROR
        proxy = Server.new(logger, proxy_host, proxy_port, target_url)
        proxy.run!


        if block_given?
          yield proxy
        end

        Thread.new do
          test.run
        end
        EM.stop_event_loop
      end

    end
  end

end
