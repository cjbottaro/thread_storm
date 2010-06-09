require "thread"

class ThreadStorm
  class Queue #:nodoc:
    
    def initialize
      @lock  = Mutex.new
      @cond  = ConditionVariable.new
      @die   = false
      @queue = []
    end
    
    # Pushes a value on the queue and wakes up the next thread waiting on #deq.
    def enq(value)
      @lock.synchronize do 
        @queue.push(value)
        @cond.signal # Wake up next thread waiting on #deq.
      end
    end
    
    # Pops a value of the queue.  Blocks if the queue is empty.
    def deq
      @lock.synchronize do
        if deq_should_block?
          @cond.wait(@lock)
        end
        if die?
          nil
        else
          @queue.pop
        end
      end
    end
    
    # Clears the queue.  Any calls to #deq will immediately return with nil.
    def die!
      @lock.synchronize do
        @die = true
        @queue.clear
        @cond.broadcast # Wake up any threads waiting on #deq.
      end
    end
  
  private
    
    def deq_should_block?
      @queue.empty? and not die?
    end
    
    def die?
      !!@die
    end
    
  end
end