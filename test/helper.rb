require 'rubygems'
require 'test/unit'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'pool_party'

class Test::Unit::TestCase
  
  def assert_in_delta(expected, actual, delta)
    assert (expected - actual).abs < delta, "#{actual} is not within #{delta} of #{expected}"
  end
  
end
