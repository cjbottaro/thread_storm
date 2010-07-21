# Things I miss from active_support.

class Array #:nodoc:
  
  def separate
    selected = []
    rejected = []
    each do |item|
      if yield(item)
        selected << item
      else
        rejected << item
      end
    end
    [selected, rejected]
  end unless method_defined?(:separate)
  
end

class Hash #:nodoc:
  
  def symbolize_keys
    inject({}){ |memo, (k, v)| memo[k.to_sym] = v; memo }
  end unless method_defined?(:symbolize_keys)
  
  def reverse_merge(other)
    other.merge(self)
  end unless method_defined?(:reverse_merge)
  
  def option_merge(options)
    symbolize_keys.reverse_merge(options)
  end
  
end

class Object #:nodoc:
  
  def metaclass
    class << self; self; end
  end
  
  def tap
    yield(self)
    self
  end unless method_defined?(:tap)
  
end