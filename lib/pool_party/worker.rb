class PoolParty
  class Worker #:nodoc:
    
    # Takes the threadsafe queue and options from the thread pool.
    def initialize(queue, options)
      @queue   = queue
      @options = options
      @thread  = Thread.new(self){ |me| me.run }
      
      # Timeout.timeout has to take a float (or nil for no timeout).
      @options[:timeout] = @options[:timeout].to_f unless @options[:timeout].nil?
    end
    
    # Pop executions and process them until we're signaled to die.
    def run
      pop_and_process_execution while not die?
    end
    
    # Pop an execution off the queue and process it, or pass off control to a different thread.
    def pop_and_process_execution
      if (execution = @queue.pop).instance_of?(Execution)
        process_execution_with_timeout(execution)
      else
        Thread.pass
      end
    end
    
    # Process the execution, handling timeouts and exceptions.
    def process_execution_with_timeout(execution)
      execution.start_time = Time.now
      begin
        timeout{ process_execution(execution) }
      rescue Timeout::Error => e
        execution.value = @options[:default_value]
        execution.timed_out = true
      rescue Exception => e
        execution.value = @options[:default_value]
        execution.exception = e
      end
      execution.finish_time = Time.now
    end
    
    # Seriously, process the execution.
    def process_execution(execution)
      execution.value = execution.block.call(*execution.args)
    end
    
    # Alias Timeout.timeout.
    def timeout
      Timeout.timeout(@options[:timeout]){ yield }
    end
    
    # So the thread pool can signal this worker's thread to end.
    def die!
      @die = true
    end
    
    # True if this worker's thread should die.
    def die?
      !!@die
    end
    
    # So the thread pool can wait for this worker's thread to end.
    def join
      @thread.join
    end
    
  end
end