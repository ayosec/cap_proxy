#!/usr/bin/env ruby

require "eventmachine"
require "optparse"
require "uri"
require "logger"


##
## Command line parser

def parse_options!
  options = {
    proxy_host: "localhost",
    proxy_port: 51001,
    verbose: false,
    target: nil
  }

  def check_port!(port_number)
    if port_number !~ /\A\d+\Z/
      STDERR.puts "Invalid value `#{port_number}`: number required"
      exit 3
    end
    port_number.to_i
  end

  begin
    OptionParser.new do |opts|
      opts.banner = "Usage: proxy [options]"

      opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
        options[:verbose] = v
      end

      opts.on("-H", "--proxy-host [HOST]", "Proxy host") do |v|
        options[:proxy_host] = v
      end

      opts.on("-P", "--proxy-port [PORT]", "Proxy port") do |v|
        options[:proxy_port] = check_port!(v)
      end

      opts.on("-t", "--target [HOST]", "Target URL") do |v|
        options[:target] = v
      end

    end.parse!
  rescue OptionParser::InvalidOption => e
    STDERR.puts e
    exit 1
  end

  if not ARGV.empty?
    STDERR.puts "Excessive arguments: #{ARGV * " "}."
    exit 2
  end

  options
end


##
## Main handlers

class RemoteConnection < EM::Connection
  attr_reader :proxy_connection

  def initialize(proxy_connection)
    @proxy_connection = proxy_connection
  end

  def receive_data(data)
    proxy_connection.handler.log.debug("Closing #{proxy_connection.head}")
    proxy_connection.send_data data
  end

  def unbind
    proxy_connection.close_connection_after_writing
  end
end

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

class ProxyHandler

  attr_reader :proxy_port, :proxy_host, :verbose, :target, :log

  def initialize(options)
    @proxy_port = options[:proxy_port]
    @proxy_host = options[:proxy_host]
    @log = Logger.new(STDOUT)

    if options[:verbose]
      @log.level = Logger::DEBUG
    end

    target = options[:target].to_s
    if target.empty?
      STDERR.puts "--target is required"
      exit 4
    else
      target = "http://#{target}" if target !~ /\Ahttps?:/
      @target = URI.parse(target)
      if @target.scheme != "http"
        STDERR.puts "Expected http:// URI in --target"
        exit 4
      end

      if @target.path != "/" and @target.path != ""
        log.warn "Ignored path #{@target.path}"
      end
    end
  end

  def run!
    EM.run do
      puts "Proxy bind to #{proxy_host}:#{proxy_port}"
      EM.start_server proxy_host, proxy_port, ProxyConnection, self
    end
  end

end

ProxyHandler.new(parse_options!).run!
