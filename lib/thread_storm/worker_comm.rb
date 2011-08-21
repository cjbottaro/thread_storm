class ThreadStorm
  # Handles synchronized communication between a storm and its workers.
  class WorkerComm #:nodoc:

    def initialize(size)
      @size = size
      @busy = 0
      @lock = Monitor.new
      @cond = @lock.new_cond
    end

    # At first I had this method just wait for a free worker and incrementing the busy count
    # was handled by the worker thread itself.  That caused a race condition in that
    # #wait_until_free_worker could be called mulitple times before any worker threads could
    # update the busy count.
    def wait_until_free_worker
      @lock.synchronize do
        @cond.wait_until{ @busy < @size }
        @busy += 1
      end
    end

    def decr_busy_worker
      @lock.synchronize do
        @busy -= 1
        @cond.signal
      end
    end

  end
end
