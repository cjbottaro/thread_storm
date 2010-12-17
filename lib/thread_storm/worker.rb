class ThreadStorm
  class Worker #:nodoc:
    attr_reader :thread
    
    def initialize(queue)
      @queue     = queue
      @thread    = Thread.new(self){ |me| me.run }
    end
    
    # Pop executions and process them until we're signaled to die.
    def run
      while (execution = @queue.dequeue)
        execution.execute
        @queue.decr_size
      end
    end
    
  end
end