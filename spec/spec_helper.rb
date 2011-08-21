$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'thread_storm'
Bundler.require(:development)

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.mock_with :rr
end

class ATC
  def initialize
    @count = 0
    @lock = Mutex.new
    @cond = ConditionVariable.new
  end
  def wait(n)
    @lock.synchronize do
      @cond.wait(@lock) while @count < n
    end
  end
  def signal(n)
    @lock.synchronize do
      @count = n
      @cond.signal
    end
  end
end
