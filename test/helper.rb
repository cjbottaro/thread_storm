require 'rubygems'
require 'test/unit'
require "set"

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'thread_storm'

class Test::Unit::TestCase
  
  def assert_in_delta(expected, actual, delta)
    assert (expected - actual).abs < delta, "#{actual} is not within #{delta} of #{expected}"
  end
  
  def assert_all_threads_worked(pool)
    assert_equal pool.threads.to_set, pool.executions.collect{ |e| e.thread }.to_set
  end
  
end
