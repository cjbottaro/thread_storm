require "monitor"

class ThreadStorm
  # Encapsulates a unit of work to be sent to the thread pool.
  class Execution
    
    class TimeoutError < Timeout::Error; end
    
    # When an execution has been created, but hasn't been scheduled to run.
    STATE_INITIALIZED = 0
    # When an execution has been scheduled to run but is waiting for an available thread.
    STATE_QUEUED      = 1
    # When an execution is running on a thread.
    STATE_STARTED     = 2
    # When an execution has finished running.
    STATE_FINISHED    = 3
    
    # A hash mapping state symbols (:initialized, :queued, :started, :finished) to their
    # corresponding state constant values.
    STATE_SYMBOLS = {
      :initialized  => STATE_INITIALIZED,
      :queued       => STATE_QUEUED,
      :started      => STATE_STARTED,
      :finished     => STATE_FINISHED
    }
    
    # Inverted STATE_SYMBOLS.
    STATE_SYMBOLS_INVERTED = STATE_SYMBOLS.invert
    
    # The arguments passed into new or ThreadStorm#execute.
    attr_reader :args
    
    # The value of an execution's block.
    attr_reader :value
    
    # If an exception was raised when running an execution, it is stored here.
    attr_reader :exception
    
    # If an execution timed out, the timeout exception is stored here.
    attr_reader :timeout_exception
    
    # Options specific to an Execution instance.  Note that you cannot modify
    # the options once ThreadStorm#execute has been called on the execution.
    attr_reader :options
    
    attr_reader :block, :thread #:nodoc:
    
    # Create an execution. The execution will be in the :initialized state. Call
    # ThreadStorm#execute to schedule the execution to be run and transition
    # it into the :queued state.
    def initialize(*args, &block)
      @options = {}
      @state = nil
      @state_at = []
      @args = args
      @value = nil
      @block = block
      @exception = nil
      @timeout = false
      @thread = nil
      @lock = Monitor.new
      @cond = @lock.new_cond
      enter_state(:initialized)
    end
    
    # Returns the state of an execution.  If _how_ is set to :sym, returns the state as symbol.
    def state(how = :const)
      if how == :sym
        STATE_SYMBOLS_INVERTED[@state] or raise RuntimeError, "invalid state: #{@state.inspect}"
      else
        @state
      end
    end
    
    # Returns true if the execution is currently in the given state.
    # _state_ can be either a state constant or symbol.
    def state?(state)
      @state == state_to_const(state)
    end
    
    # Returns true if the execution is currently in the :initialized state.
    def initialized?
      state?(STATE_INITIALIZED)
    end
    
    # Returns true if the execution is currently in the :queued state.
    def queued?
      state?(STATE_QUEUED)
    end
    
    # Returns true if the execution is currently in the :started state.
    def started?
      state?(STATE_STARTED)
    end
    
    # Returns true if the execution is currently in the :finished state.
    def finished?
      state?(STATE_FINISHED)
    end
    
    # Returns the time when the execution entered the given state.
    # _state_ can be either a state constant or symbol.
    def state_at(state)
      @state_at[state_to_const(state)]
    end
    
    # When this execution entered the :initialized state.
    def initialized_at
      state_at(:initialized)
    end
    
    # When this execution entered the :queued state.
    def queued_at
      state_at(:queued)
    end
    
    # When this execution entered the :started state.
    def started_at
      state_at(:started)
    end
    
    # When this execution entered the :finished state.
    def finished_at
      state_at(:finished)
    end
    
    # How long an execution was (or has been) in a given state.
    # _state_ can be either a state constant or symbol.
    def duration(state = :started)
      state = state_to_const(state)
      if state == @state
        Time.now - state_at(state)
      elsif state < @state and state_at(state)
        next_state_at(state) - state_at(state)
      else
        nil
      end
    end
    
    # This is soley for ThreadStorm to put the execution into the queued state.
    def queued! #:nodoc:
      options.freeze
      enter_state(STATE_QUEUED)
    end
    
    def execute #:nodoc:
      @thread = Thread.current
      enter_state(STATE_STARTED)
      do_execute
    rescue options[:timeout_error] => e
      @timeout_exception = e
      @value = options[:default_value]
    rescue Exception => e
      @exception = e
      @value = options[:default_value]
    ensure
      enter_state(STATE_FINISHED)
    end
    
    # True if this execution raised an exception.
    def exception?
      !!@exception
    end
    
    # True if the execution went over the timeout limit.
    def timeout?
      !!@timeout_exception
    end
    
    # Block until this execution has finished running. 
    def join
      @lock.synchronize{ @cond.wait_until{ finished? } }
      raise exception if exception? and options[:reraise]
      true
    end
    
    # The value returned by the execution's code block.
    # This implicitly calls join.
    def value
      join and @value
    end
    
  private
    
    # Enters _state_ doing some error checking, callbacks, and special case for entering the finished state.
    def enter_state(state) #:nodoc:
      state = state_to_const(state)
      raise RuntimeError, "invalid state transition from #{@state} to #{state}" unless @state.nil? or state > @state
      
      # If we're entering the finished state, we need to signal any threads that called join and are waiting.
      if state == STATE_FINISHED
        @lock.synchronize{ do_enter_state(state); @cond.broadcast }
      else
        do_enter_state(state)
      end
      
      if (callback = options["#{state_to_sym(state)}_callback".to_sym])
        callback.call(self)
      end
    end
    
    # Enters _state_ and set records the time.
    def do_enter_state(state)
      @state = state
      @state_at[@state] = Time.now
    end
    
    # Finds the next state from _state_ that has a state_at time.
    # Ex:
    #   [0:10, nil, 0:15, 0:20]
    #   next_state_at(0) -> 0:15
    def next_state_at(state)
      @state_at[state+1..-1].detect{ |time| !time.nil? }
    end
    
    # Execute the stored block and args, wrapping in a timeout call if needed.
    def do_execute
      timeout           = options[:timeout]
      timeout_method    = options[:timeout_method]
      
      if timeout
        timeout_method.call(timeout){ @value = block.call(*args) }
      else
        @value = block.call(*args)
      end
    end
    
    # Normalizes _state_ to a constant (integer).
    def state_to_const(state)
      if state.kind_of?(Symbol)
        STATE_SYMBOLS[state]
      else
        state
      end
    end
    
    # Normalizes _state_ to a symbol.
    def state_to_sym(state)
      if state.kind_of?(Symbol)
        state
      else
        STATE_SYMBOLS_INVERTED[state]
      end
    end
    
  end
end