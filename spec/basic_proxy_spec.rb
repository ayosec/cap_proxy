require "test_suite"
require "logger"
require "socket"

describe ProxyHandler do

  before :all do
    sem = Semaphore.new(2)

    logger = Logger.new(STDOUT)
    logger.level = Logger::ERROR
    @proxy = ProxyHandler.new(logger, "localhost", 50300, URI.parse("http://localhost:50301"))

    Thread.new do
      sem.signal
      @proxy.run!
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
  end

  after :all do
    EM.stop
  end

  it "should proxy basic HTTP requests" do
    conn = TCPSocket.new("localhost", 50300)
    conn.write("GET / HTTP/1.0\r\n\r\n")
    received = conn.read

    received.should == "TCPServer\n"
  end

  it "should capture requests" do
    pending
  end

end
