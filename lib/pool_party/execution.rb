class PoolParty
  # Encapsulates a unit of work to be sent to the thread pool.
  class Execution
    attr_writer :value, :exception #:nodoc:
    attr_reader :args, :block, :thread #:nodoc:
    
    def initialize(args, &block) #:nodoc:
      @args = args
      @block = block
      @start_time = nil
      @finish_time = nil
      @value = nil
      @exception = nil
      @timed_out = false
      @thread = nil
      @mutex = Mutex.new
      @join = ConditionVariable.new
    end
    
    def start! #:nodoc:
      @thread = Thread.current
      @start_time = Time.now
    end
    
    # True if this execution has started running.
    def started?
      !!start_time
    end
    
    # When this execution began to run.
    def start_time
      @start_time
    end
    
    def finish! #:nodoc:
      @mutex.synchronize do
        @finish_time = Time.now
        @join.signal
      end
    end
    
    # True if this execution has finished running.
    def finished?
      !!finish_time
    end
    
    # When this execution finished running (either cleanly or with error).
    def finish_time
      @finish_time
    end
    
    # How long this this execution ran for (i.e. finish_time - start_time)
    # or if it hasn't finished, how long it has been running for.
    def duration
      if finished?
        finish_time - start_time
      else
        Time.now - start_time
      end
    end
    
    def timed_out! #:nodoc:
      @timed_out = true
    end
    
    # True if the execution went over the timeout limit.
    def timed_out?
      !!@timed_out
    end
    
    # Block until this execution has finished running. 
    def join
      @mutex.synchronize do
        @join.wait(@mutex) unless finished?
      end
    end
    
    # If this execution finished with an exception, it is stored here.
    def exception
      @exception
    end
    
    # The value returned by the execution's code block.
    def value
      @value
    end
    
  end
end