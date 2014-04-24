require "eventmachine"
require "logger"

module CapProxy

  module TestWrapper

    class SimpleResponder < EM::Connection
      def receive_data(_)
        send_data "TCPServer\n"
        close_connection_after_writing
      end
    end

    def self.run(example, bind_address, target)
      em_init = Queue.new
      example_finished = EM::Queue.new

      Thread.new do
        EM.run do
          EM.error_handler do |error|
            STDERR.puts error
            STDERR.puts error.backtrace.map {|l| "\t#{l}" }
          end

          logger = Logger.new(STDERR)
          logger.level = Logger::ERROR
          proxy = Server.new(bind_address, target, logger)
          proxy.run!

          example_finished.pop do |q|
            EM.stop_event_loop
            q.push(nil)
          end

          em_init.push(proxy)
        end
      end

      proxy = em_init.pop
      if block_given?
        yield proxy
      end

      example.run

      q = Queue.new
      example_finished.push(q)
      q.pop
    end
  end

end
