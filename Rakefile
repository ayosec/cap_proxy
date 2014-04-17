
desc "Launch all tests"
task :test do
  $LOAD_PATH.unshift "#{Dir.pwd}/test"
  Dir["#{File.dirname __FILE__}/test/*_test.rb"].each do |test_file|
    require test_file
  end
end

task :default => :test
