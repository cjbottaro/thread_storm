require "monitor"

class ThreadStorm
  # Encapsulates a unit of work to be sent to the thread pool.
  #
  # Executions are in one of four states:  :new, :queued, :started or :finished.
  #
  # :new is the initial state when an execution has been created, but hasn't been scheduled to run.
  #
  # :queued is the state when an execution is scheduled and is waiting for an available thread.
  #
  # :started is the state when an execution is running its code block on an available thread.
  #
  # :finished is the state when an execution has completed running its code block.
  class Execution
    
    STATE_NEW      = 0
    STATE_QUEUED   = 1
    STATE_STARTED  = 2
    STATE_FINISHED = 3
    
    STATE_SYMBOLS = {
      :new      => STATE_NEW,
      :queued   => STATE_QUEUED,
      :started  => STATE_STARTED,
      :finished => STATE_FINISHED
    }
    
    STATE_SYMBOLS_INVERTED = STATE_SYMBOLS.invert
    
    # The arguments passed into new or ThreadStorm#execute.
    attr_reader :args
    
    # The value of an execution's block.
    attr_reader :value
    
    # If an exception was raised when running an execution, it is stored here.
    attr_reader :exception
    
    # The state of an execution (:new, :queued, :started or :finished).
    attr_reader :state
    
    attr_reader :block, :thread #:nodoc:
    
    # Create an execution.  The execution will be in the :new state.  Call
    # ThreadStorm#execute to schedule the execution to be run and transition
    # it into the :queued state.
    def initialize(*args, &block)
      @state = nil
      @state_times = {}
      @args = args
      @value = nil
      @block = block
      @exception = nil
      @timed_out = false
      @thread = nil
      @lock = Monitor.new
      @cond = @lock.new_cond
      new!
    end
    
    # The state of an execution as a symbol (See STATE_SYMBOLS).
    def state
      STATE_SYMBOLS_INVERTED[@state] or raise RuntimeError, "invalid state: #{@state.inspect}"
    end
    
    # True if an execution is in the :new state.
    def new?
      @state == STATE_NEW
    end
    
    # True if an execution is in the :queued state.
    def queued?
      @state == STATE_QUEUED
    end
    
    # True if an execution is in the :started state.
    def started?
      @state == STATE_STARTED
    end
    
    alias_method :running?, :started?
    
    # True if an execution is in the :finished state.
    def finished?
      @state == STATE_FINISHED
    end
    
    # When this execution entered the :new state.
    def new_time
      state_time(:new)
    end
    
    # When this execution entered the :queued state.
    def queue_time
      state_time(:queued)
    end
    
    # When this execution entered the :started state.
    def start_time
      state_time(:started)
    end
    
    # When this execution entered the :finished state.
    def finish_time
      state_time(:finished)
    end
    
    # When an execution entered a given state.
    # _state_ is a symbol (See STATE_SYMBOLS).
    def state_time(state)
      state = STATE_SYMBOLS[state]
      @state_times[state]
    end
    
    # How long an execution has been in a given state.
    # _state_ is a symbol (See STATE_SYMBOLS).
    def state_duration(state)
      state = STATE_SYMBOLS[state]
      if state == @state
        Time.now - @state_times[state]
      elsif state < @state
        @state_times[state+1] - @state_times[state]
      else
        nil
      end
    end
    
    # If the execution is in the :finished state, then returns finish_time - start_time (i.e. how long it ran for).
    # If the execution is in the :started state, then returns Time.now - start_time (i.e. how long it has been running for).
    # Otherwise returns nil.
    #
    # This is an alias for #state_duration(:started).
    def duration
      state_duration(:started)
    end
    
    # True if this execution raised an exception.
    def exception?
      !!@exception
    end
    
    # True if the execution went over the timeout limit.
    def timed_out?
      !!@timed_out
    end
    
    # Block until this execution has finished running. 
    def join
      @lock.synchronize do
        @cond.wait_until{ finished? }
      end
      true
    end
    
    # The value returned by the execution's code block.
    # This implicitly calls join.
    def value
      join and @value
    end
    
    def enter_state!(state) #:nodoc:
      @state = state
      @state_times[@state] = Time.now
    end
    
    def new! #:nodoc:
      enter_state!(STATE_NEW)
    end
    
    def queued! #:nodoc:
      enter_state!(STATE_QUEUED)
    end
    
    def started! #:nodoc:
      enter_state!(STATE_STARTED)
      @thread = Thread.current
    end
    
    def finished! #:nodoc:
      @lock.synchronize do
        enter_state!(STATE_FINISHED)
        @cond.signal
      end
    end
    
    def timed_out! #:nodoc:
      @timed_out = true
    end
    
    def exception!(e) #:nodoc:
      @exception = e
    end
    
    def execute! #:nodoc:
      @value = block.call(*args)
    end
    
  end
end