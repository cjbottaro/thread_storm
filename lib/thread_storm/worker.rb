class ThreadStorm
  class Worker #:nodoc:
    attr_reader :thread
    
    def initialize(queue, comm)
      @queue        = queue
      @comm         = comm
      @running      = false
      @running_lock = Monitor.new
      @running_cond = @running_lock.new_cond
      @thread       = Thread.new(self){ |me| me.run }
      wait_until_running
    end
    
    # Pop executions and process them until we're signaled to die.
    def run
      signal_running

      while (execution = @queue.dequeue)
        execution.execute
        @comm.decr_busy_worker
      end
    end

  private

    def wait_until_running
      @running_lock.synchronize do
        @running_cond.wait_until{ @running }
      end
    end

    def signal_running
      @running_lock.synchronize do
        @running = true
        @running_cond.signal
      end
    end
    
  end
end
