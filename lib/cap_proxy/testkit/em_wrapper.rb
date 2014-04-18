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

      em_init = Semaphore.new(1)
      em_stopped = Semaphore.new(1)

      proxy = nil

      Thread.new do
        EM.run do
          EM.error_handler do |error|
            STDERR.puts error
            STDERR.puts error.backtrace.map {|l| "\t#{l}" }
          end

          logger = Logger.new(STDERR)
          logger.level = Logger::ERROR
          proxy = Server.new(logger, proxy_host, proxy_port, target_url)
          proxy.run!

          EM.start_server "localhost", 50301, SimpeResponder

          em_init.signal
        end

        em_stopped.signal
      end

      em_init.wait

      if block_given?
        yield proxy
      end

      test.run
      EM.stop_event_loop
      em_stopped.wait
    end
  end

end
