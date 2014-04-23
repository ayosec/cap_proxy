# coding: utf-8

require "spec_helper"
require "net/http"

describe CapProxy::Server do

  around :each do |test|
    CapProxy::TestWrapper.run(test, "localhost:50300", "localhost:50301") do |proxy|
      EM.start_server "localhost", 50301, CapProxy::TestWrapper::SimpleResponder
      @proxy = proxy
    end
  end

  def proxy_req!(packet)
    conn = TCPSocket.new("localhost", 50300)
    conn.write(packet)
    response = conn.read(512)
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

  it "should manage chunked responsed" do
    @proxy.capture(method: "get") do |client, request|
      client.chunks_start 201, "content-type" => "text/foo"
      EM.add_timer(0.1) { client.chunks_send([-30, -100, -108, 97].pack("c*")) }
      EM.add_timer(0.3) { client.chunks_send("abc") }
      EM.add_timer(0.5) { client.chunks_finish }
    end

    start_time = Time.now.to_f
    resp = Net::HTTP.get_response(URI("http://localhost:50300"))
    resp.code.should == "201"
    resp["Content-Type"].should == "text/foo"
    resp.body.bytes.to_a.should == "✔aabc".bytes.to_a

    (Time.now.to_f - start_time).should >= 0.5
  end

end
