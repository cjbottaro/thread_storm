require 'helper'

class TestThreadStorm < Test::Unit::TestCase
  
  def new_storm(options = {})
    @storm = ThreadStorm.new(options)
  end
  
  def storm
    @storm
  end
  
  def new_execution(*args, &block)
    @storm.new_execution(*args, &block)
  end
  
  def new_controlled_execution(start, finish, value = nil)
    @controls ||= {}
    
    execution = new_execution{ nil }
    proc = Proc.new do
      send_sign(execution, start)
      wait_sign(execution, finish)
      value
    end
    execution.instance_variable_set(:@block, proc)
    
    sign = nil
    lock = Monitor.new
    cond = lock.new_cond
    @controls[execution] = [sign, lock, cond]
    
    execution
  end
  
  def wait_sign(execution, sign)
    _sign, lock, cond = @controls[execution]
    lock.synchronize{ cond.wait_until{ @controls[execution][0] == sign } }
  end
  
  def send_sign(execution, sign)
    _sign, lock, cond = @controls[execution]
    lock.synchronize{ @controls[execution][0] = sign; cond.broadcast }
  end
  
  def test_no_concurrency
    new_storm :size => 1
    e1 = new_controlled_execution(1, 2)
    e2 = new_controlled_execution(1, 2)
    e3 = new_controlled_execution(1, 2)
    storm.execute(e1)
    storm.execute(e2)
    storm.execute(e3)
    
    wait_sign(e1, 1)
    assert_equal :started, e1.state(:sym)
    assert_equal :queued,  e2.state(:sym)
    assert_equal :queued,  e3.state(:sym)
    
    send_sign(e1, 2); e1.join
    wait_sign(e2, 1)
    assert_equal :finished, e1.state(:sym)
    assert_equal :started,  e2.state(:sym)
    assert_equal :queued,   e3.state(:sym)
    
    send_sign(e2, 2); e2.join
    wait_sign(e3, 1)
    assert_equal :finished, e1.state(:sym)
    assert_equal :finished, e2.state(:sym)
    assert_equal :started,  e3.state(:sym)
    
    send_sign(e3, 2); e3.join
    assert_equal :finished, e1.state(:sym)
    assert_equal :finished, e2.state(:sym)
    assert_equal :finished, e3.state(:sym)
  end
  
  def test_partial_concurrency
    new_storm :size => 2
    e1 = new_controlled_execution(1, 2)
    e2 = new_controlled_execution(1, 2)
    e3 = new_controlled_execution(1, 2)
    storm.execute(e1)
    storm.execute(e2)
    storm.execute(e3)
    
    wait_sign(e1, 1)
    wait_sign(e2, 1)
    assert_equal :started, e1.state(:sym)
    assert_equal :started, e2.state(:sym)
    assert_equal :queued,  e3.state(:sym)
    
    send_sign(e1, 2); e1.join
    send_sign(e2, 2); e2.join
    wait_sign(e3, 1)
    assert_equal :finished, e1.state(:sym)
    assert_equal :finished, e2.state(:sym)
    assert_equal :started,  e3.state(:sym)
    
    send_sign(e3, 2); e3.join
    assert_equal :finished, e1.state(:sym)
    assert_equal :finished, e2.state(:sym)
    assert_equal :finished, e3.state(:sym)
  end
  
  def test_full_concurrency
    new_storm :size => 3
    e1 = new_controlled_execution(1, 2)
    e2 = new_controlled_execution(1, 2)
    e3 = new_controlled_execution(1, 2)
    storm.execute(e1)
    storm.execute(e2)
    storm.execute(e3)
    
    wait_sign(e1, 1)
    wait_sign(e2, 1)
    wait_sign(e3, 1)
    assert_equal :started, e1.state(:sym)
    assert_equal :started, e2.state(:sym)
    assert_equal :started, e3.state(:sym)
    
    send_sign(e1, 2); e1.join
    send_sign(e2, 2); e2.join
    send_sign(e3, 2); e3.join
    assert_equal :finished, e1.state(:sym)
    assert_equal :finished, e2.state(:sym)
    assert_equal :finished, e3.state(:sym)
  end
  
  def test_timeout
    ThreadStorm.new :size => 1, :timeout => 0.01 do |storm|
      storm.execute{ sleep(0.02) }
      storm.join
      assert_equal true, storm.executions[0].timeout?
      assert_equal nil, storm.executions[0].value
    end
  end
  
  def test_timeout_with_default_value
    ThreadStorm.new :size => 1, :timeout => 0.01, :default_value => "timed out" do |storm|
      storm.execute{ sleep(0.02) }
      storm.join
      assert_equal true, storm.executions[0].timeout?
      assert_equal "timed out", storm.executions[0].value
    end
  end
  
  def test_exception
    ThreadStorm.new :size => 1 do |storm|
      storm.execute{ raise ArgumentError, "test" }
      assert_raise(ArgumentError){ storm.join }
      assert_equal true, storm.executions[0].exception?
      assert_equal ArgumentError, storm.executions[0].exception.class
      assert_equal "test", storm.executions[0].exception.message
      storm.clear_executions # We have to clear executions here or the exception will get
                             # raised again when ThreadStorm#new eventually calls join.
    end
  end
  
  def test_shutdown
    original_thread_count = Thread.list.length
    
    storm = ThreadStorm.new :size => 3
    storm.execute{ sleep(0.01); "one" }
    storm.execute{ sleep(0.01); "two" }
    storm.execute{ sleep(0.01); "three" }
    storm.join
    
    assert_equal original_thread_count + 3, Thread.list.length
    storm.shutdown
    assert_equal original_thread_count, Thread.list.length
  end
  
  def test_shutdown_before_pop
    storm = ThreadStorm.new :size => 3
    storm.shutdown
  end
  
  def test_args
    storm = ThreadStorm.new :size => 2
    %w[one two three four five].each do |word|
      storm.execute(word){ |w| sleep(0.01); w }
    end
    storm.join
    assert_equal %w[one two three four five], storm.values
  end
  
  def test_new_with_block
    thread_count = Thread.list.length
    storm = ThreadStorm.new :size => 1 do |storm|
      storm.execute{ sleep(0.01); "one" }
      storm.execute{ sleep(0.01); "two" }
      storm.execute{ sleep(0.01); "three" }
    end
    assert_equal thread_count, Thread.list.length
    assert_equal %w[one two three], storm.values
    assert_all_threads_worked(storm)
  end
  
  def test_execute_blocks
    t1 = Thread.new do
      storm = ThreadStorm.new :size => 1, :execute_blocks => true
      storm.execute{ sleep }
      storm.execute{ nil }
    end
    t2 = Thread.new do
      storm = ThreadStorm.new :size => 1, :execute_blocks => false
      storm.execute{ sleep }
      storm.execute{ nil }
    end
    sleep(0.1) # How else??
    assert_equal "sleep", t1.status
    assert_equal false, t2.status
  end
  
  def test_clear_executions
    storm = ThreadStorm.new :size => 3
    storm.execute{ sleep }
    storm.execute{ sleep(0.1) }
    storm.execute{ sleep(0.1) }
    sleep(0.2) # Ugh another test based on sleeping.
    finished = storm.clear_executions(:finished?)
    assert_equal 2, finished.length
    assert_equal 1, storm.executions.length
  end
  
  def test_execution_blocks_again
    storm = ThreadStorm.new :size => 10, :execute_blocks => true
    20.times{ storm.execute{ sleep(rand) } }
    storm.join
    storm.shutdown
  end
  
  def test_duration
    ThreadStorm.new do |s|
      e = s.execute{ sleep(0.2) }
      e.join
      assert e.duration >= 0.2
    end
  end
  
  def test_states
    lock = Monitor.new
    cond = lock.new_cond
    sign = 1
    
    storm = ThreadStorm.new :size => 1
    storm.execute do
      lock.synchronize do
        cond.wait_until{ sign == 2 }
      end
    end
    
    execution = storm.new_execution do
      lock.synchronize do
        sign = 3
        cond.signal
        cond.wait_until{ sign == 4 }
      end
    end
    assert_equal :initialized, execution.state(:sym)
    
    storm.execute(execution)
    assert_equal :queued, execution.state(:sym)
    
    lock.synchronize{ sign = 2; cond.broadcast }
    lock.synchronize{ cond.wait_until{ sign == 3 } }
    assert_equal :started, execution.state(:sym)
    
    lock.synchronize{ sign = 4; cond.signal }
    execution.join
    assert_equal :finished, execution.state(:sym)
    
    assert_equal false, execution.exception?
    
    assert execution.initialized_at < execution.queued_at
    assert execution.queued_at < execution.started_at
    assert execution.started_at < execution.finished_at
    
    assert execution.duration(:initialized) > 0
    assert execution.duration(:queued) > 0
    assert execution.duration(:started) > 0
    assert execution.duration(:finished) > 0
    
    storm.shutdown
  end
  
  def test_global_options
    storm = ThreadStorm.new
    assert_equal ThreadStorm::DEFAULTS, storm.options
    
    ThreadStorm.options[:size] = 5
    ThreadStorm.options[:timeout] = 10
    ThreadStorm.options[:default_value] = "new_default_value"
    storm = ThreadStorm.new
    assert_not_equal ThreadStorm::DEFAULTS, storm.options
    assert_equal 5, storm.options[:size]
    assert_equal 10, storm.options[:timeout]
    assert_equal "new_default_value", storm.options[:default_value]
    
    # !IMPORTANT! So the rest of the tests work...
    ThreadStorm.options.replace(ThreadStorm::DEFAULTS)
  end
  
  def test_execution_options
    storm = ThreadStorm.new :timeout => 0.3
    e1 = storm.new_execution{ sleep }
    e2 = storm.new_execution{ sleep }
    e3 = storm.new_execution{ sleep }
    e1.options[:timeout] = 0.1
    e2.options[:timeout] = 0.2
    
    storm.run do
      storm.execute(e1)
      storm.execute(e2)
      storm.execute(e3)
    end
    assert [e1, e2, e3].all?{ |e| e.timeout? }
    
    # Yes, I know the following is a bad test...
    assert e1.duration < 0.2
    assert e2.duration < 0.3
    assert e3.duration < 0.4
    
    assert_raises(RuntimeError, TypeError){ e1.options[:timeout] = 0.4 }
  end
  
end
