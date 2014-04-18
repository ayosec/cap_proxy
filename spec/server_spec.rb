require "spec_helper"
require "logger"
require "socket"

describe CapProxy::Server do

  before :all do
    sem = Semaphore.new(2)

    logger = Logger.new(STDERR)
    logger.level = Logger::ERROR
    @proxy = CapProxy::Server.new(logger, "localhost", 50300, URI.parse("http://localhost:50301"))

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

  before :each do
    @proxy.reset_filters!
  end

  after :all do
    EM.stop
  end

  def proxy_req!(packet)
    conn = TCPSocket.new("localhost", 50300)
    conn.write(packet)
    response = conn.read(1024)
    conn.close
    response
  end

  it "should proxy basic HTTP requests" do
    proxy_req!("GET / HTTP/1.0\r\n\r\n").should == "TCPServer\n"
  end

  it "should capture requests" do
    @proxy.capture(method: "get", path: /x/) do |client, request|
      request.request_url.should include("x")
      client.respond 404, {}, "foobar"
    end

    proxy_req!("GET /a/x/ HTTP/1.0\r\n\r\n").should =~ %r[\AHTTP/1.1 404 Not Found\r\n.*foobar\Z]m
    proxy_req!("POST /a/x/ HTTP/1.0\r\n\r\n").should == "TCPServer\n"
  end

  it "should respond with custom headers" do
    @proxy.capture(method: "put") do |client, request|
      request.http_method.should == "PUT"
      client.respond 200, {"x-foo" => "that"}, "."
    end

    resp = proxy_req!("PUT / HTTP/1.0\r\n\r\n")
    resp.should =~ %r[\AHTTP/1.1 200 OK\r\n]
    resp.should include("x-foo: that\r\n")
  end

  it "should use a custom filter" do
    class CaptureAll < CapProxy::Filter
      def apply?(request)
        true
      end
    end

    @proxy.capture(CaptureAll.new) do |client, request|
      client.respond 200, {}, "-captured-"
    end

    proxy_req!("PUT / HTTP/1.0\r\n\r\n").should include("-captured-")
    proxy_req!("GET /foo HTTP/1.0\r\n\r\n").should include("-captured-")
  end


end
