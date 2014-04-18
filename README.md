# CapProxy

[![Build Status](https://travis-ci.org/ayosec/cap_proxy.svg)](https://travis-ci.org/ayosec/cap_proxy)

HTTP proxy with the ability to capture requests and generate a fake response.

This proxy is not intended to use in production environment, but in tests

## Usage

_TBD_

## Example

```ruby
describe MyApp do

  around :each do |test|
    CapProxy::TestWrapper.run(test, "localhost", 4001, "http://localhost:3000") do |proxy|
      @proxy = proxy
    end
  end

  it "should do it" do
    @proxy.capture(method: "get", path: "/users") do |client, request|
      request.request_url.should include("x")
      client.respond 404, {}, "Dummy response"
    end
  end
end
```
