class ThreadStorm
  class Worker #:nodoc:
    attr_reader :thread, :execution
    
    # Takes the threadsafe queue and options from the thread pool.
    def initialize(queue, options)
      @queue     = queue
      @options   = options
      @execution = nil # Current execution we're working on.
      @thread    = Thread.new(self){ |me| me.run }
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
      @queue.synchronize do
        if @queue.empty? and not die?
          @execution = nil   # Mark us as idle (not busy).
          @queue.signal_deq  # Signal to anyone waiting to enq that there is an idle worker.
          @queue.wait_on_enq # Become idle.
        end
        @execution = @queue.deq unless die?
      end
      process_execution_with_timeout unless die?
    end
    
    # Process the execution, handling timeouts and exceptions.
    def process_execution_with_timeout
      execution.start!
      begin
        if timeout
          timeout_method.call(timeout){ process_execution }
        else
          process_execution
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
    def process_execution
      execution.value = execution.block.call(*execution.args)
    end
    
    def busy?
      !!@execution
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