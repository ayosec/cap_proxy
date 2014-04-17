require "rspec"
require "thread"
require_relative "../lib/cap_proxy/server"

class Semaphore
  def initialize(initial)
    @value = initial
    @mutex = Mutex.new
    @waiting = []
  end

  def wait
    loop do
      @mutex.synchronize do
        return if @value < 1
        @waiting.push Thread.current
      end

      Thread.stop
    end
  end

  def signal
    @mutex.synchronize do
      @value = @value - 1
      @waiting.each {|thread| thread.run }
    end
  end
end
