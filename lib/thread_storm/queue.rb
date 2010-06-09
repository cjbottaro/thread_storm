require "thread"

class ThreadStorm
  class Queue #:nodoc:
    
    def initialize
      @lock     = Mutex.new
      @deq_cond = ConditionVariable.new
      @enq_cond = ConditionVariable.new
      @queue    = []
    end
    
    def enq(value)
      @queue.push(value)
    end
    
    def deq
      @queue.pop
    end
    
    def empty?
      @queue.empty?
    end
    
    def synchronize(&block)
      @lock.synchronize{ block.call(self) }
    end
    
    def wait_on_deq
      @deq_cond.wait(@lock)
    end
    
    def wait_on_enq
      @enq_cond.wait(@lock)
    end
    
    def signal_deq
      @deq_cond.signal
    end
    
    def signal_enq
      @enq_cond.signal
    end
    
    def broadcast_deq
      @deq_cond.broadcast
    end
    
    def broadcast_enq
      @enq_cond.broadcast
    end
    
  end
end