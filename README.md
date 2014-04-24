# CapProxy

[![Build Status](https://travis-ci.org/ayosec/cap_proxy.svg)](https://travis-ci.org/ayosec/cap_proxy)

HTTP proxy with the ability to capture requests and generate a fake response. It is *not* intended to use in production environments, but only in integration tests.

It is tested in Ruby MRI (1.9, 2.0, 2.1) and Rubinius. Check out the [Travis page](https://travis-ci.org/ayosec/cap_proxy) to see the current status on every platform. We plan to support JRuby when some concurrency issues are managed.

## Usage

### Installation

Install the gem with

    $ gem install cap_proxy

Or add it to your `Gemfile`

```ruby
group :test do
  gem "cap_proxy"
end
```

Finally, load it into your application

```ruby
require "cap_proxy/server"
```

### Create a proxy instance

The main class to use the proxy is `CapProxy::Server`. You have to indicate the address where the proxy will be listening, and the address of the HTTP server which receives every non-captured request.

When the proxy is initialized, you have to call to the `#run!` method to start the server. This method has to be invoked when [EventMachine](http://eventmachine.rubyforge.org/) is running.

```ruby
proxy = CapProxy::Server.new("localhost:1234", "localhost:5678")

EM.run do
  proxy.run!
end
```

You can use a logger with the proxy:

```ruby
logger = Logger.new(STDOUT)
proxy = CapProxy::Server.new("localhost:1234", "localhost:5678", logger)

EM.run do
  proxy.run!
end
```

Now, every connection to `http://localhost:1234` will be forwarded to `http://localhost:5678`.

### Testing

For your convenience, if you are using RSpec you can use `CapProxy::TestWrapper` to wrap every example.

```ruby
require "cap_proxy/testkit"

# ...

around :each do |example|
  CapProxy::TestWrapper.run(example, "localhost:4001", "localhost:3000") do |proxy|
    @proxy = proxy
  end
end
```

`CapProxy::TestWrapper` will initialize EventMachine, creates a proxy running in it, and launch the example in a different thread. When the example is finished, the EventMachine is stopped.

### Capturing and manipulating requests

With `#capture` you can capture any request, and generate a dummy response for it. You have to define a filter, and a block to generate the response.

```ruby
@proxy.capture(method: "get", path: "/users") do |client, request|
  client.respond 404, {}, "Dummy response"
end
```

Details about how to capture requests, and to generate a response for it, are in the section *Capturing requests*.

## Capturing requests

The first step is to define a filter. If a request matches multiple filters, it will be managed by the oldest one. If no filter matches the request, it will be forwarded to the default HTTP server.

### Defining a filter

The easiest way to define a filter is with a hash, which can contain any of the following items:

* `:method`
* `:path`
* `:headers`

`:method` can accept any string to represent a HTTP method (`"get"` and `"GET"` are equivalent).

```ruby
@proxy.capture(method: "get") { ... }
```

`:path` can be defined with a string (full URI has to match), or with a regular expression (matched with the `=~` operator).

```ruby
@proxy.capture(path: "/users") { ... }

@proxy.capture(method: "post", path: %r{/users/\d+}) { ... }
```

`:headers` expects a hash with the headers to be matched. The value of every header can be a string or a regular expression.

```ruby
@proxy.capture(path: "/", headers: { "content-type" => /json/ }) do
  ...
end
```

### Custom filters

If you need more control to filter the request, you can create your own filter

```ruby
class MyFilter < CapProxy::Filter

  def apply?(request)
    # Conditions
  end

end
```

The `#apply?` method receives an instance of `Http::Parser`, from the [http_parser.rb gem](https://github.com/tmm1/http_parser.rb). You can use methods like `http_method`, `request_url` or `headers` to query info about the request.

If `#apply?` returns `false` or `nil`, the filter will skip this request.

To use your filter, create an instance of it:

```ruby
@proxy.capture(MyFilter.new) { ... }
```

### Generating responses

The block of the `capture` method is invoked with two arguments: the first one is an instance of `CapProxy::Client`. The last one is the instance of `HTTP::Parser`.

The simplest way to generate a response is calling to `client.respond(status, headers, body)`.

```ruby
@proxy.capture(path: "/users", method: "post") do |client, request|
  client.respond 201, {"Content-Type" => "application/json"}, %q[{"id": 123}]
end
```

### Chunked responses

You can generate a response in [multiple chunks](http://en.wikipedia.org/wiki/Chunked_transfer_encoding).

First, you have to call to `client.chunks_start(status, headers)`, to initialize the chunked response. Then, for every chunk, call to `client.chunks_send(data)`. Finally, finish the connection with `client.chunks_finish`

```ruby
@proxy.capture(path: "/chunks") do |client, request|
  client.chunks_start 200, "content-type" => "text/plain"
  EM.add_timer(0.4) { client.chunks_send("Cap") }
  EM.add_timer(0.8) { client.chunks_send("Proxy\n") }
  EM.add_timer(1.2) { client.chunks_finish }
end
```

## Example

```ruby
require "cap_proxy/server"
require "cap_proxy/testkit"

describe MyApp do

  around :each do |test|
    CapProxy::TestWrapper.run(test, "localhost:4001", "localhost:3000") do |proxy|
      @proxy = proxy
    end
  end

  it "should do it" do
    @proxy.capture(method: "get", path: "/users") do |client, request|
      request.request_url.should include("foo_id")
      client.respond 404, {}, "Dummy response"
    end
  end
end
```
