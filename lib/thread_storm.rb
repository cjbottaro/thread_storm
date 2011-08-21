require "thread"
require "timeout"
require "thread_storm/active_support"
require "thread_storm/queue"
require "thread_storm/execution"
require "thread_storm/worker"
require "thread_storm/worker_comm"

# Simple but powerful thread pool implementation.
class ThreadStorm
  
  class TimeoutError < Exception; end
  
  # Version of ThreadStorm that you are using.
  VERSION = File.read(File.dirname(__FILE__)+"/../VERSION").chomp
  
  # Default options found in ThreadStorm.options.
  DEFAULTS = { :size => 2,
               :execute_blocks => false,
               :timeout => nil,
               :timeout_method => Timeout.method(:timeout),
               :timeout_exception => Timeout::Error,
               :default_value => nil,
               :reraise => true }.freeze
  
  @options = DEFAULTS.dup
  metaclass.class_eval do
    # Global options.
    attr_reader :options
  end
  
  # Options specific to a ThreadStorm instance.
  attr_reader :options
  
  # Array of executions in order as they are defined by calls to ThreadStorm#execute.
  attr_reader :executions
  
  # call-seq:
  #   new(options = {}) -> thread_storm
  #   new(options = {}){ |self| ... } -> thread_storm
  #
  # Valid _options_ are...
  #   :size => How many threads to spawn.
  #   :timeout => Max time an execution is allowed to run before terminating it.  Nil means no timeout.
  #   :timeout_method => An object that implements something like Timeout.timeout via #call..
  #   :default_value => Value of an execution if it times out or errors..
  #   :reraise => True if you want exceptions to be reraised when ThreadStorm#join is called.
  #   :execute_blocks => True if you want #execute to block until there is an available thread.
  #
  # For defaults, see DEFAULTS.
  #
  # When given a block, ThreadStorm#join and ThreadStorm#shutdown are called for you.  In other words...
  #   ThreadStorm.new do |storm|
  #     storm.execute{ sleep(1) }
  #   end
  # ...is the same as...
  #   storm = ThreadStorm.new
  #   storm.execute{ sleep(1) }
  #   storm.join
  #   storm.shutdown
  def initialize(options = {})

    # Merge options with the global options.
    @options = options.reverse_merge(self.class.options)

    # Setup the queue.
    @queue = Queue.new(@options[:size])

    # Initialize our executions tracking.
    @executions = []

    # Initialize the worker communication.
    @worker_comm = WorkerComm.new(@options[:size])

    # Initialize the workers and wait for them to start.
    @workers = @options[:size].times.collect{ Worker.new(@queue, @worker_comm) }

    # Run if block is given.
    run{ yield(self) } if block_given?
  end
  
  # This is like Execution.new except it inherits options from the storm instance.
  # This method is best explained with examples:
  #   storm.new_execution                     <=> Execution.new(storm.options)
  #   storm.new_execution(:timeout => 1)      <=> Execution.new(storm.options.merge(:timeout => 1))
  #   storm.new_execution(arg1, arg2){ blah } <=> Execution.new(storm.options).define(arg1, arg1){ blah }
  # Note in these examples Execution is an alias for ThreadStorm::Execution.
  def new_execution(*args, &block)
    
    # It has to be this way because of how options are merged.
    
    if block_given?
      Execution.new(options.dup).define(*args, &block)
    elsif args.length == 0
      Execution.new(options.dup)
    elsif args.length == 1 and args.first.kind_of?(Hash)
      Execution.new(options.merge(args.first))
    else
      raise ArgumentError, "illegal call-seq"
    end
  end
  
  def run
    yield(self)
    join
    shutdown
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
      execution = new_execution(*args, &block)
    elsif args.length == 1 and args.first.instance_of?(Execution)
      execution = args.first
    else
      raise ArgumentError, "execution or arguments and block expected"
    end
    
    @worker_comm.wait_until_free_worker if options[:execute_blocks]

    execution.queued!
    @executions << execution
    @queue.enqueue(execution)
    
    execution
  end
  
  # Block until all pending executions are finished running.
  # Reraises any exceptions caused by executions unless <tt>:reraise => false</tt> was passed to ThreadStorm#new.
  def join
    @executions.each do |execution|
      execution.join
    end
  end
  
  # Calls ThreadStorm#join, then collects the values of each execution.
  def values
    join and @executions.collect{ |execution| execution.value }
  end
  
  # Signals the worker threads to terminate immediately (ignoring any pending
  # executions) and blocks until they do.
  def shutdown(how = :graceful)
    case how
    when :graceful
      @queue.shutdown
      threads.each{ |thread| thread.join }
    when :now
      threads.each do |thread|
        thread.kill
        Thread.pass while thread.alive?
      end
    end
    true
  end
  
  # Returns an array of Ruby threads in the pool.
  def threads
    @workers.collect{ |worker| worker.thread }
  end

  alias_method :primitives, :threads
  
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
  
end
