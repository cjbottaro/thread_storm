require "monitor"

class ThreadStorm
  # This is tricky... we need to maintain both real queue size and fake queue size.
  # If we use just the real queue size alone, then we will see the following
  # (incorrect) behavior:
  #   storm = ThreadStorm.new :size => 2, :execute_blocks => true
  #   storm.execute{ sleep }
  #   storm.execute{ sleep }
  #   storm.execute{ sleep } # Doesn't block, but should.
  #   storm.execute{ sleep } # Finally blocks.
  # The reason is that popping the queue (and thus decrementing its size) does not
  # imply that the worker thread has actually finished the execution and is ready to
  # accept another one.
  class Queue #:nodoc:
    
    def initialize(max_size, enqueue_blocks)
      @max_size       = max_size
      @enqueue_blocks = enqueue_blocks
      @size           = 0
      @array          = []
      @lock           = Monitor.new
      @cond1          = @lock.new_cond # Wish I could come up with better names.
      @cond2          = @lock.new_cond
    end
    
    def synchronize(&block)
      @lock.synchronize{ yield(self) }
    end
    
    # +enqueue+ needs to wait on the fake size, otherwise @max_size+1 calls to
    # +enqueue+ could be made when @enqueue_blocks is true.
    def enqueue(item)
      @lock.synchronize do
        @cond2.wait_until{ @size < @max_size } if @enqueue_blocks
        @size += 1
        @array << item
        @cond1.signal
      end
    end
    
    # +dequeue+ needs to wait until the real size, otherwise a single call to
    # +enqueue+ could result to multiple successful calls to +dequeue+ before
    # a call to +decr_size+ is made.
    def dequeue
      @lock.synchronize do
        @cond1.wait_until{ @array.size > 0 }
        @array.shift
      end
    end
    
    # Decrement the fake size, thus signaling that we're ready to call +enqueue+.
    def decr_size
      @lock.synchronize do
        @size -= 1 unless @size == 0
        @cond2.signal
      end
    end
    
    def shutdown
      @lock.synchronize do
        @array = [nil] * @max_size
        @size = @max_size
        @cond1.broadcast
      end
    end
    
  end
end