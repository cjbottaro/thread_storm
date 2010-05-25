# Things I miss from active_support.

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
  
  def returning(value)
    yield(value)
    value
  end unless method_defined?(:returning)
  
end