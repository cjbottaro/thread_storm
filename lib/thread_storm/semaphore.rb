require "monitor"

class ThreadStorm
  class Semaphore #:nodoc:
    
    def initialize(max = 1)
      @lock  = Monitor.new
      @cond  = @lock.new_cond
      @max   = max
      @count = 0
    end
    
    def incr
      @lock.synchronize do
        @cond.wait_while{ @count == @max }
        @count += 1
      end
    end
    
    def decr
      @lock.synchronize do
        @count -= 1 unless @count == 0
        @cond.signal
      end
    end
    
  end
end