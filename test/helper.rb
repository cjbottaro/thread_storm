require 'rubygems'
require 'test/unit'
require "set"

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'thread_storm'
require 'timecop'

require "thread_storm/atc"
Atc = ThreadStorm::Atc

class Test::Unit::TestCase

  def setup
    # Only 1 thread should be running at the start of each test.
    Thread.list.each do |thread|
      if thread != Thread.current
        while thread.alive?
          thread.kill
          Thread.pass
        end
      end
    end
  end

  def teardown
    assert_equal 1, Thread.list.length, "#{Thread.list.length - 1} thread(s) not cleaned up"
  end  
  
  def assert_in_delta(expected, actual, delta)
    assert (expected - actual).abs < delta, "#{actual} is not within #{delta} of #{expected}"
  end
  
  def assert_all_threads_worked(pool)
    assert_equal pool.threads.to_set, pool.executions.collect{ |e| e.thread }.to_set
  end
  
end
