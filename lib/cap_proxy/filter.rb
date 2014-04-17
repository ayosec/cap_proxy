require "http_parser"

module CapProxy

  class InvalidFilterParam < RuntimeError; end
  class InvalidRule < RuntimeError; end

  class Filter
    def self.from_hash(hash)
      RulesEngine.new(
        hash.each_pair.map do |param, value|
          case param
          when :method
            [ [ :method, value.upcase ] ]
          when :path
            case value
            when Regexp
              [ [ :path_regexp, value ] ]
            when String
              [ [ :path, value ] ]
            else
              raise InvalidFilterParam.new("Invalid value #{value.inspect} for :path")
            end
          when :headers
            value.each_pair.map do |header, value|
              case value
              when String
                [ :header, header.downcase, value ]
              when Regexp
                [ :header_regexp, header.downcase, value ]
              else
                raise InvalidRule.new("Invalid header rule #{value.inspect}")
              end
            end
          else
            raise InvalidFilterParam.new("Invalid item #{param.inspect}")
          end
        end.inject {|a, b| a.concat(b)}
      )
    end

    def apply?(request)
      raise NotImplementedError.new("apply? have to be implemented by inherited classes")
    end
  end

  class RulesEngine < Filter
    def initialize(rules)
      raise InvalidRule.new("At least one rule is required") if rules.empty?
      @rules = rules
    end

    def apply?(request)
      @rules.all? do |rule|
        case rule[0]
        when :method
          rule[1] == request.http_method
        when :path_regexp
          request.request_url =~ rule[1]
        when :path
          request.request_url == rule[1]
        when :header_regexp
          request.headers.each_pair.any? do |rh, rv|
            rh.downcase == rule[1] && rv =~ rule[2]
          end
        when :header
          request.headers.each_pair.any? do |rh, rv|
            rh.downcase == rule[1] && rv == rule[2]
          end
        else
          raise InvalidRule.new("Invalid rule #{rule.inspect}")
        end
      end
    end
  end

end
