require "./lib/cap_proxy/version"

Gem::Specification.new do |s|
  s.name        = "cap_proxy"
  s.version     = CapProxy::VERSION
  s.licenses    = ["MIT"]
  s.summary     = "HTTP Proxy with ability to capture and manipulate requests."
  s.description = "HTTP proxy with the ability to capture requests and generate a fake response. It is *not* intended to use in production environments, but only in integration tests." 
  s.authors     = ["Ayose Cazorla"]
  s.email       = "ayosec@gmail.com"
  s.files       = `git ls-files lib/ spec/ README.md`.split("\n")
  s.homepage    = "https://github.com/ayosec/cap_proxy"

  s.add_runtime_dependency "eventmachine", "~> 1.0.3"
  s.add_runtime_dependency "http_parser.rb"
  s.add_runtime_dependency "thread_safe"
  s.add_development_dependency "rake", "~> 10.3.0"
  s.add_development_dependency "rspec"
end
