require "thread"
require "timeout"
require "thread_storm/active_support"
require "thread_storm/queue"
require "thread_storm/execution"
require "thread_storm/worker"

class ThreadStorm
  
  # Array of executions in order as defined by calls to ThreadStorm#execute.
  attr_reader :executions
  
  # Valid options are
  #   :size => How many threads to spawn.  Default is 2.
  #   :timeout => Max time an execution is allowed to run before terminating it.  Default is nil (no timeout).
  #   :timeout_method => An object that implements something like Timeout.timeout via #call.  Default is Timeout.method(:timeout).
  #   :default_value => Value of an execution if it times out or errors.  Default is nil.
  #   :reraise => True if you want exceptions reraised when ThreadStorm#join is called.  Default is true.
  def initialize(options = {})
    @options = options.option_merge :size => 2,
                                    :timeout => nil,
                                    :timeout_method => Timeout.method(:timeout),
                                    :default_value => nil,
                                    :reraise => true,
                                    :execute_blocks => false
    #@queue = Queue.new # This is threadsafe.
    @queue = []
    @executions = []
    @lock = Mutex.new
    @free_cond = ConditionVariable.new
    @full_cond = ConditionVariable.new
    @workers = (1..@options[:size]).collect{ Worker.new(@queue, @options, @lock, @free_cond, @full_cond) }
    @start_time = Time.now
    if block_given?
      yield(self)
      join
      shutdown
    end
  end
  
  def size
    @options[:size]
  end
  
  def default_value
    @options[:default_value]
  end
  
  def reraise?
    @options[:reraise]
  end
  
  def execute_blocks?
    @options[:execute_blocks]
  end
  
  def all_workers_busy?
    @workers.all?{ |worker| worker.busy? }
  end
  
  # Create and execution and schedules it to be run by the thread pool.
  # Return value is a ThreadStorm::Execution.
  def execute(*args, &block)
    Execution.new(args, &block).tap do |execution|
      execution.value = default_value
      @executions << execution
      @lock.synchronize do
        @free_cond.wait(@lock) if execute_blocks? and all_workers_busy?
        @queue << execution
        @full_cond.signal
      end
    end
  end
  
  # Block until all pending executions are finished running.
  # Reraises any exceptions caused by executions unless <tt>:reraise => false</tt> was passed to ThreadStorm#new.
  def join
    @executions.each do |execution|
      execution.join
      raise execution.exception if execution.exception and reraise?
    end
  end
  
  # Calls ThreadStorm#join, then collects the values of each execution.
  def values
    join
    @executions.collect{ |execution| execution.value }
  end
  
  # Signals the worker threads to terminate immediately (ignoring any pending
  # executions) and blocks until they do.
  def shutdown
    @workers.each{ |worker| worker.die! }
    @free_cond.broadcast
    @full_cond.broadcast
    @workers.each{ |worker| worker.thread.join }
    true
  end
  
  # Returns an array of threads in the pool.
  def threads
    @workers.collect{ |worker| worker.thread }
  end
  
end