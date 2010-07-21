class ThreadStorm
  class Worker #:nodoc:
    attr_reader :thread, :execution
    
    # Takes the threadsafe queue and options from the thread pool.
    def initialize(queue, sentinel)
      @queue     = queue
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
      @sentinel.synchronize do |e_cond, p_cond|
        # Become idle and signal that we're idle.
        @execution = nil
        e_cond.signal
        
        # Give up the lock and wait until there is work to do.
        p_cond.wait_while{ @queue.empty? }
        
        # Get the work to do (implicitly becoming busy).
        @execution = @queue.shift
      end
      
      process_execution_with_timeout unless die?
    end
    
    # Process the execution, handling timeouts and exceptions.
    def process_execution_with_timeout
      execution.started!
      execution.prepare!
      
      # Pull out some options.
      timeout = execution.options[:timeout]
      timeout_method = execution.options[:timeout_method]
      
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
    
    def busy?
      !!@execution and not die?
    end
    
    # True if this worker's thread should die.
    def die?
      @execution == :die
    end
    
  end
end