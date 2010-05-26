require "thread"
require "thread_pool/active_support"
require "thread_pool/execution"
require "thread_pool/worker"

class ThreadPool
  
  # Array of executions in order as defined by calls to ThreadPool#execute.
  attr_reader :executions
  
  # Valid options are
  #   :size => How many threads to spawn.  Default is 2.
  #   :timeout => Max time an execution is allowed to run before terminating it.  Default is nil (no timeout).
  #   :default_value => Value of an execution if it times out or errors.  Default is nil.
  #   :reraise => True if you want exceptions reraised when ThreadPool#join is called.  Default is true.
  def initialize(options = {})
    @options = options.option_merge :size => 2,
                                    :timeout => nil,
                                    :default_value => nil,
                                    :reraise => true
    @queue = Queue.new # This is threadsafe.
    @executions = []
    @workers = (1..@options[:size]).collect{ Worker.new(@queue, @options) }
    @start_time = Time.now
  end
  
  # Create and execution and schedules it to be run by the thread pool.
  # Return value is a ThreadPool::Execution.
  def execute(*args, &block)
    returning(Execution.new(args, &block)) do |execution|
      @executions << execution
      @queue << execution
    end
  end
  
  # Block until all pending executions are finished running.
  # Reraises any exceptions caused by executions unless <tt>:reraise => false</tt> was passed to ThreadPool#new.
  def join
    @executions.each do |execution|
      Thread.pass while not execution.finished?
      raise execution.exception if execution.exception and @options[:reraise]
    end
    @finish_time = Time.now
  end
  
  # Calls ThreadPool#join, then collects the values of each execution.
  def values
    join
    @executions.collect{ |execution| execution.value }
  end
  
  # Returns how long the thread pool as been running in seconds.
  def duration
    if @finish_time
      @finish_time - @start_time
    else
      Time.now - @start_time
    end
  end
  
  # Signals the worker threads to terminate and blocks until they do.
  def shutdown
    Thread.pass while not @queue.empty?
    @workers.each{ |worker| worker.die!; @queue << :wakeup }
    @workers.each{ |worker| worker.join }
    @finish_time = Time.now
    true
  end
  
end