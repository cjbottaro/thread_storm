require "monitor"

class ThreadStorm
  # This class manages synchronous access to shared resources.
  # This is tricky... the queue and queue size have to be managed separately or the
  # :execute_blocks option will not work properly.  If we use just a queue alone,
  # using Queue#size to determine when to make ThreadStorm#execute block, we will
  # see the following (incorrect) behavior:
  #   storm = ThreadStorm.new :size => 2, :execute_blocks => true
  #   storm.execute{ sleep }
  #   storm.execute{ sleep }
  #   storm.execute{ sleep } # Doesn't block, but should.
  #   storm.execute{ sleep } # Finally blocks.
  # The reason is that popping the queue (and thus decrementing its size) does not
  # imply that the worker thread is actually finished the execution and is ready to
  # accept another one.
  class Sentinel #:nodoc:
    
    def initialize(max_size)
      @queue = []
      @max_queue_size = max_size
      @queue_size = 0
      @lock = Monitor.new
      @queue_size_cond = @lock.new_cond
      @queue_cond = @lock.new_cond
    end
    
    # Monitors are reentrant, so it's ok to use this inconjunction with the
    # other methods below.
    def synchronize
      @lock.synchronize{ yield(self) }
    end
    
    # Increments the queue_size, blocking if it's equal to max_queue_size.
    def incr_queue_size
      @lock.synchronize do
        @queue_size_cond.wait_until{ @queue_size < @max_queue_size }
        @queue_size += 1
      end
    end
    
    # Decrements the queue_size, making sure it doesn't go below zero and
    # signaling any threads waiting on the queue_size to drop below max_queue_size.
    def decr_queue_size
      @lock.synchronize do
        @queue_size -= 1 if @queue_size > 0
        @queue_size_cond.signal
      end
    end
    
    # Push an item onto the queue, signaling any threads waiting on the queue
    # not to be empty.
    def push_queue(item)
      @lock.synchronize do
        @queue << item
        @queue_cond.signal
      end
    end
    
    # Pop the queue, blocking until the queue isn't empty.
    def pop_queue
      @lock.synchronize do
        @queue_cond.wait_while{ @queue.empty? }
        @queue.shift
      end
    end
    
    # Replace the queue with shutdown messages and signal all threads waiting
    # on the queue not to be empty.
    def shutdown_queue
      @lock.synchronize do
        @queue = [:die] * @max_queue_size
        @queue_cond.broadcast
      end
    end
    
  end
end