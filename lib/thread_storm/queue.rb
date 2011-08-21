require "monitor"

class ThreadStorm
  class Queue #:nodoc:
    attr_reader :array # This is for testing only!
    attr_reader :size  # So is this!
    
    def initialize(size)
      @size  = size
      @array = []
      @lock  = Monitor.new
      @cond  = @lock.new_cond
    end
    
    def enqueue(item)
      synchronize do
        @array.push(item)
        @cond.signal
      end
    end
    
    # Blocks if the queue is empty.
    def dequeue
      synchronize do
        @cond.wait_until{ @array.size > 0 }
        @array.shift
      end
    end
    
    def shutdown
      synchronize do
        @array = [nil] * @size
        @cond.broadcast
      end
    end
    
  private

    def synchronize(&block)
      @lock.synchronize{ yield(self) }
    end
    
  end
end
