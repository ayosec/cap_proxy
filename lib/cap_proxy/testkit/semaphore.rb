require "thread"

module CapProxy
  class Semaphore
    def initialize(initial)
      @value = initial
      @mutex = Mutex.new
      @waiting = []
    end

    def wait(expected = 0)
      loop do
        @mutex.synchronize do
          return if @value <= expected
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
end
