require 'helper'

class TestExecution < Test::Unit::TestCase
  
  def setup
    @sign = nil
    @lock = Monitor.new
    @cond = @lock.new_cond
  end
  
  def new_execution(*args, &block)
    block = Proc.new{ nil } unless block_given?
    ThreadStorm::Execution.new(*args, &block).tap do |execution|
      execution.options.replace :timeout => nil,
                                :timeout_method => Proc.new{ |seconds, &block| Timeout.timeout(seconds, ThreadStorm::Execution::TimeoutError, &block) },
                                :timeout_exception => ThreadStorm::Execution::TimeoutError,
                                :default_value => nil,
                                :reraise => false
    end
  end
  
  def wait_until_sign(i)
    @lock.synchronize do
      @cond.wait_until{ @sign == i }
    end
  end
  
  def set_sign(i)
    @lock.synchronize do
      @sign = i
      @cond.signal
    end
  end
  
  def test_execute
    execution = new_execution{ 1 }
    execution.execute
    assert ! execution.exception?
    assert ! execution.timeout?
    assert_equal 1, execution.value
  end
  
  def test_exception
    execution = new_execution{ raise RuntimeError, "blah"; 1 }
    execution.options[:default_value] = 2
    execution.execute
    assert execution.exception?
    assert ! execution.timeout?
    assert_equal 2, execution.value
  end
  
  def test_timeout
    execution = new_execution{ sleep(1); 1 }
    execution.options.merge! :default_value => 2,
                             :timeout => 0.001
    execution.execute
    assert ! execution.exception?
    assert execution.timeout?
    assert execution.exception.kind_of?(ThreadStorm::Execution::TimeoutError)
    assert_equal 2, execution.value
  end
  
  def test_timeout_exception
    timeout_exception = Class.new(RuntimeError)
    execution = new_execution{ sleep(1); 1 }
    execution.options.merge! :default_value => 2,
                             :timeout => 0.001,
                             :timeout_method => Proc.new{ |secs, &block| Timeout.timeout(secs, timeout_exception){ block.call } },
                             :timeout_exception => timeout_exception
    execution.execute
    assert ! execution.exception?
    assert execution.timeout?
    assert execution.exception.kind_of?(timeout_exception)
    assert_equal 2, execution.value
  end
  
  def test_states
    execution = new_execution do
      set_sign(1)
      wait_until_sign(2)
    end
    
    assert_equal :initialized, execution.state(:sym)
    
    execution.queued!
    assert_equal :queued, execution.state(:sym)
    
    Thread.new{ execution.execute }
    wait_until_sign(1)
    assert_equal :started, execution.state(:sym)
    
    set_sign(2)
    execution.join
    assert_equal :finished, execution.state(:sym)
  end
  
  def test_duration
    time, execution = Time.now, nil
    Timecop.freeze(time){ execution = ThreadStorm::Execution.new{ "done" } }
    Timecop.freeze(time += 1){ execution.queued! }
    assert_equal 1, execution.duration(:initialized)
    
    # The queued state is still going on, so the duration should change each time we call it.
    Timecop.freeze(time += 2){ assert_equal 2, execution.duration(:queued) }
    Timecop.freeze(time += 3){ assert_equal 5, execution.duration(:queued) }
    
    # Make sure duration doesn't crash if we call it for a state that hasn't started yet.
    assert_equal nil, execution.duration(:started)
    
    # The execution has been in the queued state for 5 seconds already (see above).
    Timecop.freeze(time += 4){ execution.execute }
    assert_equal 9, execution.duration(:queued)
  end
  
  def test_duration_with_skipped_states
    time, execution = Time.now, nil
    Timecop.freeze(time){ execution = ThreadStorm::Execution.new{ "done" } }
    Timecop.freeze(time += 5){ execution.execute } # Skip over the queued state.
    assert_equal 5, execution.duration(:initialized)
    assert_equal nil, execution.duration(:queued)
  end
  
  def test_reraise
    klass = Class.new(RuntimeError)
    
    execution = new_execution{ nil }
    execution.options[:reraise] = true
    execution.execute
    assert_nothing_raised{ execution.join }
    
    execution = new_execution{ raise klass }
    execution.options[:reraise] = true
    execution.execute
    assert_raise(klass){ execution.join }
  end
  
  def test_new_with_options
    old_options = ThreadStorm.options.dup
    ThreadStorm.options[:timeout] = 10
    execution = ThreadStorm::Execution.new
    assert_equal 10, execution.options[:timeout]
    execution = ThreadStorm::Execution.new :timeout => 5
    assert_equal 5, execution.options[:timeout]
    ThreadStorm.options.replace(old_options) # Be sure to restore to previous state.
  end
  
end