require 'helper'

class TestThreadStorm < Test::Unit::TestCase
  
  def test_no_concurrency
    storm = ThreadStorm.new :size => 1
    storm.execute{ sleep(0.01); "one" }
    storm.execute{ sleep(0.01); "two" }
    storm.execute{ sleep(0.01); "three" }
    assert_equal %w[one two three], storm.values
    assert_all_threads_worked(storm)
  end
  
  def test_partial_concurrency
    storm = ThreadStorm.new :size => 2
    storm.execute{ sleep(0.01); "one" }
    storm.execute{ sleep(0.01); "two" }
    storm.execute{ sleep(0.01); "three" }
    assert_equal %w[one two three], storm.values
    assert_all_threads_worked(storm)
  end
  
  def test_full_concurrency
    storm = ThreadStorm.new :size => 3
    storm.execute{ sleep(0.01); "one" }
    storm.execute{ sleep(0.01); "two" }
    storm.execute{ sleep(0.01); "three" }
    assert_equal %w[one two three], storm.values
    assert_all_threads_worked(storm)
  end
  
  def test_timeout_no_concurrency
    storm = ThreadStorm.new :size => 1, :timeout => 0.015
    storm.execute{ sleep(0.01); "one" }
    storm.execute{ sleep(0.02); "two" }
    storm.execute{ sleep(0.01); "three" }
    assert_equal ["one", nil, "three"], storm.values
    assert storm.executions[1].timed_out?
    assert_all_threads_worked(storm)
  end
  
  # Tricky...
  # 1 0.01s  ----
  # 2 0.015s ------
  # 3 0.01s      ----
  def test_timeout_partial_concurrency
    storm = ThreadStorm.new :size => 2, :timeout => 0.015
    storm.execute{ sleep(0.01); "one" }
    storm.execute{ sleep(0.02); "two" }
    storm.execute{ sleep(0.01); "three" }
    assert_equal ["one", nil, "three"], storm.values
    assert storm.executions[1].timed_out?
    assert_all_threads_worked(storm)
  end
  
  def test_timeout_full_concurrency
    storm = ThreadStorm.new :size => 3, :timeout => 0.015
    storm.execute{ sleep(0.01); "one" }
    storm.execute{ sleep(0.02); "two" }
    storm.execute{ sleep(0.01); "three" }
    assert_equal ["one", nil, "three"], storm.values
    assert storm.executions[1].timed_out?
    assert_all_threads_worked(storm)
  end
  
  def test_timeout_with_default_value
    storm = ThreadStorm.new :size => 1, :timeout => 0.015, :default_value => "timed out"
    storm.execute{ sleep(0.01); "one" }
    storm.execute{ sleep(0.02); "two" }
    storm.execute{ sleep(0.01); "three" }
    assert_equal ["one", "timed out", "three"], storm.values
    assert storm.executions[1].timed_out?
    assert_all_threads_worked(storm)
  end
  
  def test_exception_handling
    storm = ThreadStorm.new :size => 1, :reraise => false do |s|
      s.execute{ raise ArgumentError, "test" }
    end
    execution = storm.executions.first
    assert execution.exception?
    assert execution.exception.class == ArgumentError
    assert execution.exception.message == "test"
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
  
  def test_for_deadlocks
    ThreadStorm.new :size => 10, :execute_blocks => true do |storm|
      20.times do
        storm.execute do
          ThreadStorm.new :size => 10, :timeout => 0.5 do |storm2|
            20.times{ storm2.execute{ sleep(rand) } }
          end
        end
      end
    end
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
    var  = 1
    
    storm = ThreadStorm.new :size => 1
    storm.execute do
      lock.synchronize do
        cond.wait_until{ var == 2 }
      end
    end
    
    execution = ThreadStorm::Execution.new do
      lock.synchronize do
        var = 3
        cond.signal
        cond.wait_until{ var == 4 }
        var = 5
        cond.signal
      end
    end
    assert_equal :new, execution.state
    
    storm.execute(execution)
    assert_equal :queued, execution.state
    
    lock.synchronize{ var = 2; cond.broadcast }
    lock.synchronize{ cond.wait_until{ var == 3 } }
    assert_equal :started, execution.state
    
    lock.synchronize{ var = 4; cond.signal }
    lock.synchronize{ cond.wait_until{ var == 5 } }
    assert_equal :finished, execution.state
    
    assert_equal false, execution.exception?
    
    assert execution.new_time < execution.queue_time
    assert execution.queue_time < execution.start_time
    assert execution.start_time < execution.finish_time
    
    assert execution.state_duration(:new) > 0
    assert execution.state_duration(:queued) > 0
    assert execution.state_duration(:started) > 0
    assert execution.state_duration(:finished) > 0
    
    storm.shutdown
  end
  
  def test_global_options
    storm = ThreadStorm.new
    assert_equal ThreadStorm::DEFAULT_OPTIONS, storm.options
    
    ThreadStorm.options[:size] = 5
    ThreadStorm.options[:timeout] = 10
    ThreadStorm.options[:default_value] = "new_default_value"
    storm = ThreadStorm.new
    assert_not_equal ThreadStorm::DEFAULT_OPTIONS, storm.options
    assert_equal 5, storm.options[:size]
    assert_equal 10, storm.options[:timeout]
    assert_equal "new_default_value", storm.options[:default_value]
    
    # !IMPORTANT! So the rest of the tests work...
    ThreadStorm.options.replace(ThreadStorm::DEFAULT_OPTIONS)
  end
  
  def test_execution_options
    e1 = ThreadStorm::Execution.new{ sleep }
    e2 = ThreadStorm::Execution.new{ sleep }
    e3 = ThreadStorm::Execution.new{ sleep }
    e1.options[:timeout] = 0.1
    e2.options[:timeout] = 0.2
    ThreadStorm.new :timeout => 0.3 do |storm|
      storm.execute(e1)
      storm.execute(e2)
      storm.execute(e3)
    end
    assert [e1, e2, e3].all?{ |e| e.timed_out? }
    
    # Yes, I know the following is a bad test...
    assert e1.duration < 0.2
    assert e2.duration < 0.3
    assert e3.duration < 0.4
    
    assert_raises(RuntimeError){ e1.options = { :timeout => 0.4 } }
    assert_raises(RuntimeError, TypeError){ e1.options[:timeout] = 0.4 }
  end
  
end
