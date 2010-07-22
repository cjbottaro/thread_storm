class ThreadStorm
  class Worker #:nodoc:
    attr_reader :thread, :execution
    
    # Takes the threadsafe queue and options from the thread pool.
    def initialize(sentinel)
      @sentinel  = sentinel
      @execution = nil # Current execution we're working on.
      @thread    = Thread.new(self){ |me| me.run }
    end
    
    # Pop executions and process them until we're signaled to die.
    def run
      pop_and_process_execution while not die?
    end
    
    # Pop an execution off the queue and process it, or pass off control to a different thread.
    def pop_and_process_execution
      @execution = @sentinel.pop_queue
      if not die?
        process_execution_with_timeout
        @sentinel.decr_queue_size
      end
    end
    
    # Process the execution, handling timeouts and exceptions.
    def process_execution_with_timeout
      # Pull out some options.
      timeout = execution.options[:timeout]
      timeout_method = execution.options[:timeout_method]
      
      execution.started!
      begin
        if timeout
          timeout_method.call(timeout){ execution.execute! }
        else
          execution.execute!
        end
      rescue Timeout::Error => e
        execution.timed_out!
      rescue Exception => e
        execution.exception!(e)
      ensure
        execution.finished!
      end
    end
    
    # True if this worker's thread should die.
    def die?
      @execution == :die
    end
    
  end
end