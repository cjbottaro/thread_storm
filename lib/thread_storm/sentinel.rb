require "monitor"

class ThreadStorm
  class Sentinel #:nodoc:
    attr_reader :e_cond, :p_cond
    
    def initialize
      @lock = Monitor.new
      @e_cond = @lock.new_cond # execute condition
      @p_cond = @lock.new_cond # pop condition
    end
    
    def synchronize
      @lock.synchronize{ yield(@e_cond, @p_cond) }
    end
    
  end
end