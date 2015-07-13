# Try represents a computation that may either result in an
# exception, or return a value.
# Instances of Try(T) are either an instance of `Success(T)`
# or `Failure(T)`
# Eg.
# ```
# a = Success(Symbol).new :hello
# a.get   # => :hello
# a = Failure(Symbol).new(Exception.new "Error")
# a.get   # => Raises Exception("Error")
# # Pattern match over a Try(T)
# case a
# when Success
#   # do something with result
# when Failure
#   # handle exception
# end
# ```
abstract class Try(T)
  # Returns the value from this `Success` or throws the
  # exception if `Failure`
  abstract def get

  # Returns true if `Try` is a `Success`. false otherwise
  abstract def success?

  # Returns true if `Try` is a `Failure`. false otherwise
  abstract def failure?
  
  # Converts this to a Failure if the predicate is not satisfied
  abstract def select(&block : T->Bool)
end

class Success(T) < Try(T)
  getter value
  def initialize(value : T)
    @value = value
  end

  def failure?
    false
  end

  def success?
    true
  end

  def get
    @value
  end

  def select(&block : T->Bool)
    if block.call(@value)
      self
    else
      Failure(T).new(PredicateFailureException.new)
    end
  end
end

class Failure(T) < Try(T)
  getter error
  def initialize(error : Exception)
    @error = error
  end

  def get
    raise @error
  end

  def failure?
    true
  end

  def success?
    false
  end

  def select
    self
  end
end
