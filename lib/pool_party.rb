require "thread"
require "timeout"
require "pool_party/active_support"
require "pool_party/execution"
require "pool_party/worker"

class PoolParty
  
  # Array of executions in order as defined by calls to PoolParty#execute.
  attr_reader :executions
  
  # Valid options are
  #   :size => How many threads to spawn.  Default is 2.
  #   :timeout => Max time an execution is allowed to run before terminating it.  Default is nil (no timeout).
  #   :timeout_method => An object that implements something like Timeout.timeout via #call.  Default is Timeout.method(:timeout).
  #   :default_value => Value of an execution if it times out or errors.  Default is nil.
  #   :reraise => True if you want exceptions reraised when PoolParty#join is called.  Default is true.
  def initialize(options = {})
    @options = options.option_merge :size => 2,
                                    :timeout => nil,
                                    :timeout_method => Timeout.method(:timeout),
                                    :default_value => nil,
                                    :reraise => true
    @queue = Queue.new # This is threadsafe.
    @executions = []
    @workers = (1..@options[:size]).collect{ Worker.new(@queue, @options) }
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
  
  # Create and execution and schedules it to be run by the thread pool.
  # Return value is a PoolParty::Execution.
  def execute(*args, &block)
    Execution.new(args, &block).tap do |execution|
      execution.value = default_value
      @executions << execution
      @queue << execution
    end
  end
  
  # Block until all pending executions are finished running.
  # Reraises any exceptions caused by executions unless <tt>:reraise => false</tt> was passed to PoolParty#new.
  def join
    @executions.each do |execution|
      execution.join
      raise execution.exception if execution.exception and reraise?
    end
  end
  
  # Calls PoolParty#join, then collects the values of each execution.
  def values
    join
    @executions.collect{ |execution| execution.value }
  end
  
  # Signals the worker threads to terminate immediately (ignoring any pending
  # executions) and blocks until they do.
  def shutdown
    @workers.each{ |worker| worker.die! }
    @workers.length.times{ @queue << :wakeup }
    @workers.each{ |worker| worker.thread.join }
    true
  end
  
  # Returns an array of threads in the pool.
  def threads
    @workers.collect{ |worker| worker.thread }
  end
  
end