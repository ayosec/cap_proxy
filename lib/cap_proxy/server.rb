require "eventmachine"
require_relative "client"

module CapProxy
  class Server

    attr_reader :proxy_port, :proxy_host, :target, :log

    def initialize(log, proxy_host, proxy_port, target)
      @log = log
      @proxy_port = proxy_port
      @proxy_host = proxy_host
      @target = target
    end

    def run!
      EM.run do
        log.info "Proxy bind to #{proxy_host}:#{proxy_port}"
        EM.start_server proxy_host, proxy_port, Client, self
      end
    end

  end
end
