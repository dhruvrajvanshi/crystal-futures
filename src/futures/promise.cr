module Futures
  # Promise is an objectwhich can be completed with a value
  # or failed with an exception.
  # Eg.
  # ```
  # p = Promise(Symbol).new
  # f = p.future
  # f.on_success do |val|
  #   puts "Future completed with value #{val}"
  # end
  # p.success(:Hello)
  # ```
  # ```
  # "Future completed with value Hello"
  # ```
  class Promise(T)
    getter future
    def initialize
      @completion_channel = Channel::Unbuffered(Symbol).new
      @completed = false
      @result = None(Try(T)).new
      @future = Future(T).new do
        @completion_channel.receive
        v = @result.get.get
      end
    end

    # Returns whether the promise has already been  completed with
    # a value or an exception
    def completed?
      @completed
    end

    # Tries to complete the promise with either a value ot exception
    def try_complete(result : Try(T))
      if completed?
        false
      else
        @completed = true
        @result = Some(Try(T)).new result
        @completion_channel.send :completed
        @future = Future(T).new do
          v = nil
          case @result.get
          when Success
            v = @result.get.get
          when Failure
            raise (@result.get.as Failure).error
          end
          v.as T
        end
        true
      end
    end

    # Completes the promise with a value
    def success(value : T)
      unless try_complete Success(T).new(value)
        raise IllegalStateException.new("Promise\#success called on \
          already completed promise")
      end
    end

    # Completes the promise with an exception
    def failure(error : Exception)
      unless try_complete Failure(T).new(error)
        raise IllegalStateException.new("Promise\#failure called on \
          already completed promise")
      end
    end
  end
end
