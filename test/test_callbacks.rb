require 'helper'

class TestCallbacks < Test::Unit::TestCase
  
  # The general premise of this test is that we assign a callback to increment
  # this counter when we enter each state.
  def test_state_callbacks
    counter = 0
    callback = Proc.new{ counter += 1 }
    
    storm = ThreadStorm.new
    execution = storm.new_execution{ "done" }
    assert_equal 0, counter
    execution.options.merge! :queued_callback      => callback,
                             :started_callback     => callback,
                             :finished_callback    => callback
        
    execution.queued!
    assert_equal 1, counter
    
    execution.execute
    assert_equal 3, counter
  end
  
  def test_callback_exception
    storm = ThreadStorm.new :size => 1
    storm.options[:queued_callback] = Proc.new{ raise RuntimeError, "oops" }
    e = storm.execute{ "success" }
    storm.join
    assert_equal false, e.exception?
    assert_equal "success", e.value
    assert_equal true, e.callback_exception?
    assert_equal false, e.callback_exception?(:started)
    assert_equal true, e.callback_exception?(:queued)
    assert_equal RuntimeError, e.callback_exception(:queued).class
    assert_equal "oops", e.callback_exception(:queued).message
    assert storm.threads.all?{ |thread| thread.alive? }
  end
  
end