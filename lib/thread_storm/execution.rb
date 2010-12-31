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
      @callback_exceptions = {}
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
      self.state == state_to_const(state)
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
      timeout           = options[:timeout]
      timeout_method    = options[:timeout_method]
      timeout_exception = options[:timeout_exception]
      default_value     = options[:default_value]
      
      @thread = Thread.current
      enter_state(STATE_STARTED)
      
      begin
        timeout_method.call(timeout){ @value = @block.call(*args) }
      rescue timeout_exception => e
        @exception = e
        @value = default_value
      rescue Exception => e
        @exception = e
        @value = default_value
      ensure
        enter_state(STATE_FINISHED)
      end
    end
    
    # True if the execution finished without failure (exception) or timeout.
    def success?
      state?(:finished) and !exception? and !timeout?
    end
    
    # True if this execution raised an exception.
    def failure?
      state?(:finished) and !!@exception and !timeout?
    end
    
    # Deprecated... for backwards compatibility.
    alias_method :exception?, :failure? #:nodoc:
    
    # True if the execution went over the timeout limit.
    def timeout?
      !!@exception and @exception.kind_of?(options[:timeout_exception])
    end
    
    def callback_exception?(state = nil)
      ![nil, {}].include?(callback_exception(state))
    end
    
    def callback_exception(state = nil)
      if state
        @callback_exceptions[state]
      else
        @callback_exceptions
      end
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
      
      # We need state changes and callbacks to be atomic so that if we query a state change
      # we can be sure that its corresponding callback has finished running as well. Thus
      # we need to make sure to synchronize querying state (see #state).
      
      handle_callback(state)
      
      @lock.synchronize do
        do_enter_state(state)
        @cond.broadcast if state == STATE_FINISHED # Wake any threads that called join and are waiting.
      end
    end
    
    # Enters _state_ and set records the time.
    def do_enter_state(state)
      @state = state
      @state_at[@state] = Time.now
    end
    
    def handle_callback(state)
      state = state_to_sym(state)
      callback = options["#{state}_callback".to_sym]
      return unless callback
      begin
        callback.call(self)
      rescue Exception => e
        @callback_exceptions[state] = e
      end
    end
    
    # Finds the next state from _state_ that has a state_at time.
    # Ex:
    #   [0:10, nil, 0:15, 0:20]
    #   next_state_at(0) -> 0:15
    def next_state_at(state)
      @state_at[state+1..-1].detect{ |time| !time.nil? }
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