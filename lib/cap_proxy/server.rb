require "eventmachine"
require "thread_safe"
require_relative "client"
require_relative "filter"

module CapProxy
  class Server

    attr_reader :proxy_port, :proxy_host, :target_host, :target_port, :log, :filters

    def initialize(bind_address, target, log = nil)

      proxy_host, proxy_port = bind_address.split(":", 2)
      target_host, target_port = target.split(":", 2)

      @log = log
      @proxy_port = proxy_port
      @proxy_host = proxy_host
      @target_host = target_host
      @target_port = target_port
      reset_filters!
    end

    def reset_filters!
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
      log.info "CapProxy: Listening on #{proxy_host}:#{proxy_port}" if log
      EM.start_server proxy_host, proxy_port, Client, self
    end

  end
end
