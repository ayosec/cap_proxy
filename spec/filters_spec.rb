require "spec_helper"

describe CapProxy::Filter do

  context "Filters from hashes" do

    def hash_filter?(hash, request)
      parser = HTTP::RequestParser.new
      parser << request

      filter = CapProxy::Filter.from_hash(hash)
      filter.apply?(parser)
    end

    it "filter by method and path" do
      hash_filter?(
        {method: "get", path: "/foo/bar"},
        %[GET /foo/bar HTTP/1.0\r\n\r\n]
      ).should be_true

      hash_filter?(
        {method: "post", path: "/foo/bar"},
        %[GET /foo/bar HTTP/1.0\r\n\r\n]
      ).should be_false

      hash_filter?(
        {method: "post", path: %r{/foo/bar/(\d+)}},
        %[GET /foo/bar/100 HTTP/1.0\r\n\r\n]
      ).should be_false
    end

    it "filter by path and headers" do

      hash_filter?(
        {
          path: "/",
          headers: {
            "content-type" => /json/
          }
        },
        %[GET / HTTP/1.0\r\nContent-Type: application/json\r\n\r\n]
      ).should be_true

      hash_filter?(
        {
          path: "/",
          headers: {
            "content-type" => /json/,
            "user-agent" => "none"
          }
        },
        %[GET / HTTP/1.0\r\nContent-Type: application/json\r\n\r\n]
      ).should be_false

      hash_filter?(
        {
          path: "/",
          headers: {
            "user-agent" => "none",
            "Accept" => "*"
          }
        },
        %[GET / HTTP/1.0\r\n] +
        %[User-Agent: none\r\n] +
        %[accept: *\r\n] +
        %[\r\n]
      ).should be_true
    end

  end

end
