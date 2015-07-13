# A Future represents an asynchronous computation that
# returns a value.
# Callbacks can be registered against futures to
# run when the computation completes or fails
# 
# Eg.
# ```
# a = Future.new do
#   someTimeConsumingOperation()
# end
# a.on_success do |val|
#   doSomethingWithResult val
# end
# ```
# You can compose new futures using existing ones by
# calling `map` on them. Composed futures will succeed
# only when parent succeeds.
# 
# Eg.
# ```
# b = a.map do |x|
#   x + 1
# end
# ```
class Future(T)
  getter value
  # Constructor for a future
  # Call Future.new with a block to get a future value
  # Pass in an optional `ExecutionContext` do define
  # execution behaviour of the Future. By default, it
  # creates a new `InfiniteFiberExecutionContext` for
  # each instance.  
  def initialize(
    @execution_context = InfiniteFiberExecutionContext.new,
    &block : -> T)
    @completed = false
    @succeeded = false
    @failed = false
    @value = None(Try(T)).new
    @blocked_on_this = 0
    @on_failure = [] of Exception+ -> Void
    @on_success = [] of T -> Void
    @on_complete = [] of (Future(T)) -> Void
    @completion_channel = UnbufferedChannel(Int32).new
    @block = block
    @process = [->(v : T){v}]
    execute()
  end


  # Returns a Future with the function applied to 
  # the result
  def map(&block : T->U)
    Future(U).new @execution_context, do
      block.call(self.get)
    end
  end

  # Returns a new future that succeeds if current
  # future succeeds and it's value matches the given
  # predicate
  def select(&block : T -> Bool)
    Future(T).new @execution_context, do
      if val = block.call(self.get)
        return @value.get.get
      else
        raise PredicateFailureException.new "Future select predicate failed on value #{val}"
      end
    end
  end

  # Alias for `Future.select`
  def filter(&block : T -> Bool)
    select do |val|
      block.call(val)
    end
  end


  # Return a future whose exceptions are handled by
  # the block.
  # Eg.
  # ```
  # a = Future.new { networkCall }
  # a.recover do |e|
  #   case e
  #   when Timeout
  #     "Something"
  #   when ServerError
  #     "Something Else"
  #   else
  #     # Remember to raise e in the else case
  #     raise e
  #   end
  # end
  # ```
  def recover(&block : Exception -> T)
    Future(T).new @execution_context, do
      begin
        self.get
      rescue e
        block.call(e)
      end
    end
  end

  # Register a callback to be called when the Future
  # succeeds. The callback is called with the value of
  # the future
  # Eg.
  # ```
  # f.on_success do |value|
  #   do_something_with_value value
  # end
  # ```
  def on_success(&block : T -> _)
    @on_success << block
    if(@succeeded)
      @execution_context.execute do
        block.call(@value.get.get as T)
      end
    end
    self
  end

  # Register a callback to be called when the Future
  # fails
  def on_failure(&block : Exception+ -> _)
    @on_failure << block
    if(@failed)
      @execution_context.execute do
        block.call(self.error as Exception)
      end
    end
    self
  end

  # Register a callback to be called when the Future
  # completes. The callback will be called an instance of
  # `Try(T)`
  # Eg.
  # ```
  # f.on_complete do |t|
  #   case t
  #   when Success
  #     print "Got #{t.get}"
  #   when Failure
  #     raise t.error
  #   end
  # end
  # ```
  def on_complete(&block : Future(T) -> _)
    @on_complete << block
    if @completed
      @execution_context.execute do
        block.call(self)
      end
    end
    self
  end

  # Returns true if computation completed or error thrown
  # false otherwise
  def completed?
    return @completed
  end

  # Returns true if processing succeeded.
  def succeeded?
    return @succeeded
  end

  # Returns true if processing failed
  def failed?
    return @failed
  end

  # Blocks untill future to complete and returns
  # the value. Raises exception failure occurs. Returns the
  # value if already complete
  def get
    if @completed
      @value.get.get
    else
      @blocked_on_this += 1
      @completion_channel.receive
      @value.get.get
    end
  end

  # This returns the error produced by the Future if any.
  # If the future isn't complete or it completed successfully,
  # it returns nil. This makes it indistinguishable from success
  # in case of a future of type Nil.
  # Don't use this method. Use `Future#get` instead to get
  # a single value which indicates whether Future is complete
  # or not(`None`/`Some`) and whether the operation was a 
  # success or failure(`Success`/`Failure`).
  # To get the error of a failed future, do
  # ```
  # future.get.error
  # ```
  # Note that this will result in a NoSuchElementException
  # in case the future hasn't been completed
  def error
    case @value
    when None(Try(T))
      nil
    when Some(Try(T))
      v = @value.get
      case v
      when Success(T)
        nil
      when Failure(T)
        v.error
      end
    end
  end

  private def execute()
    @execution_context.execute do
      begin
        @value = Some(Try(T)).new(Success(T).new @block.call)
        @succeeded = true
        @failed = false
        @on_success.each do |callback|
          @execution_context.execute do 
            callback.call(@value.get.get)
          end
        end
      rescue e
        @value = Some(Try(T)).new(Failure(T).new e)
        @failed = true
        @succeeded = false
        @execution_context.execute do
          @on_failure.each do |callback|
            callback.call(e)
          end
        end
      ensure
        @completed = true
        @on_complete.each do |callback|
          @execution_context.execute do
            callback.call(self)
          end
        end

        # Send a signal to for each thread blocked
        # on this Future
        @blocked_on_this.times do
          @completion_channel.send(0)
        end
      end
    end
  end
end