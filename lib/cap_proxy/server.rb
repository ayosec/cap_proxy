require "eventmachine"
require "thread_safe"
require_relative "client"
require_relative "filter"

module CapProxy
  class Server

    attr_reader :proxy_port, :proxy_host, :target, :log, :filters

    def initialize(log, proxy_host, proxy_port, target)
      @log = log
      @proxy_port = proxy_port
      @proxy_host = proxy_host
      @target = target
      @filters = ThreadSafe::Array.new
    end

    def capture(filter_param, &handler)
      filter =
        case filter_param
        when Hash
          Filter.from_hash(filter_param)
        when Filter
          filter_param
        else
          raise RuntimeError("#capture requires a hash or a Filter object")
        end

      @filters.push filter: filter, handler: handler
      filter
    end

    def run!
      EM.run do
        EM.error_handler do |error|
          STDERR.puts error
          STDERR.puts error.backtrace.map {|l| "\t#{l}" }
        end

        log.info "Proxy bind to #{proxy_host}:#{proxy_port}"
        EM.start_server proxy_host, proxy_port, Client, self
      end
    end

  end
end
