class ThreadStorm
  class Worker #:nodoc:
    attr_reader :thread
    
    # Takes the threadsafe queue and options from the thread pool.
    def initialize(queue, options)
      @queue   = queue
      @options = options
      @thread  = Thread.new(self){ |me| me.run }
    end
    
    def timeout
      @timeout ||= @options[:timeout]
    end
    
    def timeout_method
      @timeout_method ||= @options[:timeout_method]
    end
    
    # Pop executions and process them until we're signaled to die.
    def run
      pop_and_process_execution while not die?
    end
    
    # Pop an execution off the queue and process it, or pass off control to a different thread.
    def pop_and_process_execution
      execution = @queue.deq and process_execution_with_timeout(execution)
    end
    
    # Process the execution, handling timeouts and exceptions.
    def process_execution_with_timeout(execution)
      execution.start!
      begin
        if timeout
          timeout_method.call(timeout){ process_execution(execution) }
        else
          process_execution(execution)
        end
      rescue Timeout::Error => e
        execution.timed_out!
      rescue Exception => e
        execution.exception = e
      ensure
        execution.finish!
      end
    end
    
    # Seriously, process the execution.
    def process_execution(execution)
      execution.value = execution.block.call(*execution.args)
    end
    
    # So the thread pool can signal this worker's thread to end.
    def die!
      @die = true
    end
    
    # True if this worker's thread should die.
    def die?
      !!@die
    end
    
  end
end