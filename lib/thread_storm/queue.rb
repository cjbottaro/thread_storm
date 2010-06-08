require "thread"

class ThreadStorm
  class Queue #:nodoc:
    
    def initialize
      @lock  = Mutex.new
      @cond  = ConditionVariable.new
      @die   = false
      @queue = []
    end
    
    # Pushes a value on the queue and wakes up the next thread waiting on #pop.
    def push(value)
      @lock.synchronize do 
        @queue.push(value)
        @cond.signal # Wake up next thread waiting on #pop.
      end
    end
    
    # Pops a value of the queue.  Blocks if the queue is empty.
    def pop
      @lock.synchronize do
        @cond.wait(@lock) if @queue.empty? and not die?
        @queue.pop
      end
    end
    
    # Clears the queue.  Any calls to #pop will immediately return with nil.
    def die!
      @lock.synchronize do
        @die = true
        @queue.clear
        @cond.broadcast # Wake up any threads waiting on #pop.
      end
    end
  
  private
  
    def die?
      !!@die
    end
    
  end
end