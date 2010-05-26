require 'helper'

class TestPoolParty < Test::Unit::TestCase
  
  def test_no_concurrency
    pool = PoolParty.new :size => 1
    pool.execute{ sleep(0.01); "one" }
    pool.execute{ sleep(0.01); "two" }
    pool.execute{ sleep(0.01); "three" }
    assert_equal %w[one two three], pool.values
    assert_in_delta 0.03, pool.duration, 0.001
  end
  
  def test_partial_concurrency
    pool = PoolParty.new :size => 2
    pool.execute{ sleep(0.01); "one" }
    pool.execute{ sleep(0.01); "two" }
    pool.execute{ sleep(0.01); "three" }
    assert_equal %w[one two three], pool.values
    assert_in_delta 0.02, pool.duration, 0.001
  end
  
  def test_full_concurrency
    pool = PoolParty.new :size => 3
    pool.execute{ sleep(0.01); "one" }
    pool.execute{ sleep(0.01); "two" }
    pool.execute{ sleep(0.01); "three" }
    assert_equal %w[one two three], pool.values
    assert_in_delta 0.01, pool.duration, 0.001
  end
  
  def test_timeout_no_concurrency
    pool = PoolParty.new :size => 1, :timeout => 0.015
    pool.execute{ sleep(0.01); "one" }
    pool.execute{ sleep(0.02); "two" }
    pool.execute{ sleep(0.01); "three" }
    assert_equal ["one", nil, "three"], pool.values
    assert_in_delta 0.035, pool.duration, 0.001
    assert pool.executions[1].timed_out?
    assert_in_delta 0.015, pool.executions[1].duration, 0.001
  end
  
  # Tricky...
  # 1 0.01s  ----
  # 2 0.015s ------
  # 3 0.01s      ----
  def test_timeout_partial_concurrency
    pool = PoolParty.new :size => 2, :timeout => 0.015
    pool.execute{ sleep(0.01); "one" }
    pool.execute{ sleep(0.02); "two" }
    pool.execute{ sleep(0.01); "three" }
    assert_equal ["one", nil, "three"], pool.values
    assert_in_delta 0.02, pool.duration, 0.001
    assert pool.executions[1].timed_out?
    assert_in_delta 0.015, pool.executions[1].duration, 0.001
  end
  
  def test_timeout_full_concurrency
    pool = PoolParty.new :size => 3, :timeout => 0.015
    pool.execute{ sleep(0.01); "one" }
    pool.execute{ sleep(0.02); "two" }
    pool.execute{ sleep(0.01); "three" }
    assert_equal ["one", nil, "three"], pool.values
    assert_in_delta 0.015, pool.duration, 0.001
    assert pool.executions[1].timed_out?
    assert_in_delta 0.015, pool.executions[1].duration, 0.001
  end
  
  def test_timeout_with_default_value
    pool = PoolParty.new :size => 1, :timeout => 0.015, :default_value => "timed out"
    pool.execute{ sleep(0.01); "one" }
    pool.execute{ sleep(0.02); "two" }
    pool.execute{ sleep(0.01); "three" }
    assert_equal ["one", "timed out", "three"], pool.values
    assert_in_delta 0.035, pool.duration, 0.001
    assert pool.executions[1].timed_out?
    assert_in_delta 0.015, pool.executions[1].duration, 0.001
  end
  
  def test_shutdown
    original_thread_count = Thread.list.length
    
    pool = PoolParty.new :size => 3
    pool.execute{ sleep(0.01); "one" }
    pool.execute{ sleep(0.01); "two" }
    pool.execute{ sleep(0.01); "three" }
    pool.join
    
    assert_equal original_thread_count + 3, Thread.list.length
    pool.shutdown
    assert_equal original_thread_count, Thread.list.length
  end
  
  def test_args
    pool = PoolParty.new :size => 2
    %w[one two three four five].each do |word|
      pool.execute(word){ |w| sleep(0.01); w }
    end
    pool.join
    assert_equal %w[one two three four five], pool.values
  end
  
  def test_new_with_block
    thread_count = Thread.list.length
    pool = PoolParty.new :size => 1 do |party|
      party.execute{ sleep(0.01); "one" }
      party.execute{ sleep(0.01); "two" }
      party.execute{ sleep(0.01); "three" }
    end
    assert_equal thread_count, Thread.list.length
    assert_equal %w[one two three], pool.values
    assert_in_delta 0.03, pool.duration, 0.001
  end
  
end
