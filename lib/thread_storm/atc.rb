class ThreadStorm
  # Air traffic controller.
  # This is just a class to help testing.  It provides an easy way to control execution of threads.
  class Atc #:nodoc:

    def initialize(options = {})
      @timeout = options[:timeout]
      @signal  = 0
      @lock    = Mutex.new
      @cond    = ConditionVariable.new
    end

    # Returns true if condition it's waiting on happened, false otherwise.
    # If a timeout isn't specified, it will wait indefinitely for the condition.
    def wait(condition, timeout = nil)
      timeout ||= @timeout
      @lock.synchronize do
        if timeout
          if @signal != condition
            @cond.wait(@lock, timeout)
            return false if @signal != condition
          end
        else
          @cond.wait(@lock) while @signal != condition
        end
      end
      true
    end

    # Signal a condition happened.
    def signal(condition)
      @lock.synchronize do
        @signal = condition
        @cond.signal
      end
    end

  end
end
