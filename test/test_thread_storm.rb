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
    30.times{ storm.execute{ sleep(rand) } }
    storm.join
    storm.shutdown
  end
  
  def test_for_deadlocks
    ThreadStorm.new :size => 10, :execute_blocks => true do |storm|
      50.times do
        storm.execute do
          ThreadStorm.new :size => 10, :timeout => 0.5 do |storm2|
            50.times{ storm2.execute{ sleep(rand) } }
          end
        end
      end
    end
  end
  
end
