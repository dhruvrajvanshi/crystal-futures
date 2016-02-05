module Futures
  # This is raised when either complete, success or failure is called
  # on an already completed promise.
  class IllegalStateException < Exception
  end

  # If you select over a `Future` with a predicate that returns
  # false fot the value of the Future, the resulting future
  # fails with this exception
  class PredicateFailureException < Exception
  end

  # Raised when `Try(T)#get` is called on a `Failure(T)` instance
  class NoSuchElementException < Exception
  end
end
