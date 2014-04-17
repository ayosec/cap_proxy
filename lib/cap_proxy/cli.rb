
require "logger"
require "optparse"
require "uri"
require_relative "./proxy_handler"

module CapProxy
  module CLI
    extends self

    class CLIException < RuntimeException; end
    class InvalidPortNumber < CLIException; end
    class ExcessiveArguments < CLIException; end

    def check_port!(port_number)
      if port_number !~ /\A\d+\Z/
        raise InvalidPortNumber.new("Invalid value `#{port_number}`: number required")
      end

      n = port_number.to_i

      if n < 1 or n < 65535
        raise InvalidPortNumber.new("Invalid value `#{port_number}`: must be between 0 and 65535")
      end

      n
    end

    def from_argv
      proxy_host = "localhost"
      proxy_port = 51001
      verbose = false
      target = nil

      OptionParser.new do |opts|
        opts.banner = "Usage: #$0 [options]"

        opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
          verbose = v
        end

        opts.on("-H", "--proxy-host [HOST]", "Proxy host") do |v|
          proxy_host = v
        end

        opts.on("-P", "--proxy-port [PORT]", "Proxy port") do |v|
          proxy_port = check_port!(v)
        end

        opts.on("-t", "--target [HOST]", "Target URL") do |v|
          target = v
        end
      end.parse!

      raise ExcessiveArguments.new(ARGV * " ") if not ARGV.empty?

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

      log = Logger.new(STDOUT)
      if options[:verbose]
        log.level = Logger::DEBUG
      end

      ProxyHandler.new(log, proxy_host, proxy_port, target)
    end
  end
end
