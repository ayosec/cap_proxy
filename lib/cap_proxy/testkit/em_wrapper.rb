require "eventmachine"
require "uri"
require "logger"

module CapProxy

  module TestWrapper

    class SimpleResponder < EM::Connection
      def receive_data(_)
        send_data "TCPServer\n"
        close_connection_after_writing
      end
    end

    def self.run(test, bind_address, target)

      EM.run do

        proxy = nil

        EM.error_handler do |error|
          STDERR.puts error
          STDERR.puts error.backtrace.map {|l| "\t#{l}" }
        end

        logger = Logger.new(STDERR)
        logger.level = Logger::ERROR
        proxy = Server.new(bind_address, target, logger)
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
