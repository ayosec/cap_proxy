require "test_suite"
require "logger"
require "socket"

class BasicProxyTest < Test::Unit::TestCase

  def logger
    Logger.new(STDOUT).tap do |log|
      log.level = Logger::ERROR
    end
  end

  def test_proxy

    sem = Semaphore.new(2)

    Thread.new do
      proxy = ProxyHandler.new(logger, "localhost", 50300, URI.parse("http://localhost:50301"))
      sem.signal
      proxy.run!
    end

    server = Thread.new do
      socket = TCPServer.new(50301)
      sem.signal
      loop do
        client = socket.accept
        client.puts "TCPServer"
        client.close
      end
    end

    sem.wait

    conn = TCPSocket.new("localhost", 50300)
    conn.write("GET / HTTP/1.0\r\n\r\n")
    assert_equal "TCPServer\n", conn.read

  end

end
