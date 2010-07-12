require "thread"
require "timeout"
require "thread_storm/active_support"
require "thread_storm/sentinel"
require "thread_storm/execution"
require "thread_storm/worker"

# Simple but powerful thread pool implementation.
class ThreadStorm
  
  # Array of executions in order as they are defined by calls to ThreadStorm#execute.
  attr_reader :executions
  
  # call-seq:
  #   new(options = {}) -> thread_storm
  #   new(options = {}){ |self| ... } -> thread_storm
  #
  # Valid options are
  #   :size => How many threads to spawn.  Default is 2.
  #   :timeout => Max time an execution is allowed to run before terminating it.  Default is nil (no timeout).
  #   :timeout_method => An object that implements something like Timeout.timeout via #call.  Default is Timeout.method(:timeout).
  #   :default_value => Value of an execution if it times out or errors.  Default is nil.
  #   :reraise => True if you want exceptions reraised when ThreadStorm#join is called.  Default is true.
  #   :execute_blocks => True if you want #execute to block until there is an available thread.  Default is false.
  # When given a block, #join and #shutdown are called for you.  In other words...
  #   ThreadStorm.new do |storm|
  #     storm.execute{ sleep(1) }
  #   end
  # ...is the same as...
  #   storm = ThreadStorm.new
  #   storm.execute{ sleep(1) }
  #   storm.join
  #   storm.shutdown
  def initialize(options = {})
    @options = options.option_merge :size => 2,
                                    :timeout => nil,
                                    :timeout_method => Timeout.method(:timeout),
                                    :default_value => nil,
                                    :reraise => true,
                                    :execute_blocks => false
    @sentinel = Sentinel.new
    @queue = []
    @executions = []
    @workers = (1..@options[:size]).collect{ Worker.new(@queue, @sentinel, @options) }
    if block_given?
      yield(self)
      join
      shutdown
    end
  end
  
  # Returns the size of the thread pool (i.e. the :size option in new).
  def size
    @options[:size]
  end
  
  # call-seq:
  #   storm.execute(*args){ |*args| ... } -> execution
  #   storm.execute(execution) -> execution
  #
  # Schedules an execution to be run (i.e. moves it to the :queued state).
  # When given a block, it is the same as
  #   execution = ThreadStorm::Execution.new(*args){ |*args| ... }
  #   storm.execute(execution)
  def execute(*args, &block)
    if block_given?
      execution = Execution.new(*args, &block)
    elsif args.length == 1 and args.first.instance_of?(Execution)
      execution = args.first
    else
      raise ArgumentError, "execution or arguments and block expected"
    end
    
    # Oh, gross.
    execution.instance_variable_set("@value", default_value)
    
    @sentinel.synchronize do |e_cond, p_cond|
      e_cond.wait_while{ all_workers_busy? } if execute_blocks?
      @executions << execution
      @queue << execution
      execution.queued!
      p_cond.signal
    end
    
    execution
  end
  
  # Block until all pending executions are finished running.
  # Reraises any exceptions caused by executions unless <tt>:reraise => false</tt> was passed to ThreadStorm#new.
  def join
    @executions.each do |execution|
      execution.join
      raise execution.exception if execution.exception? and reraise?
    end
  end
  
  # Calls ThreadStorm#join, then collects the values of each execution.
  def values
    join and @executions.collect{ |execution| execution.value }
  end
  
  # Signals the worker threads to terminate immediately (ignoring any pending
  # executions) and blocks until they do.
  def shutdown
    @sentinel.synchronize do |e_cond, p_cond|
      @queue.replace([:die] * size)
      p_cond.broadcast
    end
    @workers.each{ |worker| worker.thread.join }
    true
  end
  
  # Returns an array of Ruby threads in the pool.
  def threads
    @workers.collect{ |worker| worker.thread }
  end
  
  # Removes executions stored at ThreadStorm#executions.  You can selectively remove
  # them by passing in a block or a symbol.  The following two lines are equivalent.
  #   storm.clear_executions(:finished?)
  #   storm.clear_executions{ |e| e.finished? }
  # Because of the nature of threading, the following code could happen:
  #   storm.clear_executions(:finished?)
  #   storm.executions.any?{ |e| e.finished? }
  # Some executions could have finished between the two calls.
  def clear_executions(method_name = nil, &block)
    cleared, @executions = @executions.separate do |execution|
      if block_given?
        yield(execution)
      elsif method_name.nil?
        true
      else
        execution.send(method_name)
      end
    end
    cleared
  end
  
private
  
  def default_value #:nodoc:
    @options[:default_value]
  end
  
  def reraise? #:nodoc:
    @options[:reraise]
  end
  
  def execute_blocks? #:nodoc:
    @options[:execute_blocks]
  end
  
  def all_workers_busy? #:nodoc:
    @workers.all?{ |worker| worker.busy? }
  end
  
end