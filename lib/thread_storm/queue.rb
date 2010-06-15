require "monitor"

class ThreadStorm
  class Queue #:nodoc:
    attr_reader :lock, :cond
    
    def initialize(size)
      @size   = size
      @lock   = Monitor.new
      @cond   = @lock.new_cond
      @queue  = []
    end
    
    def enq(value)
      @lock.synchronize do
        @queue.push(value)
        @cond.signal
      end
    end
    
    def deq
      @lock.synchronize do
        @cond.wait_while{ @queue.empty? }
        @queue.pop
      end
    end
    
    def shutdown
      @lock.synchronize do
        @queue.clear
        @size.times{ @queue.push(nil) }
        @cond.broadcast
      end
    end
    
  end
end