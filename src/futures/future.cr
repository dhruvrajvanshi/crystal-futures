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
# a.onSuccess do |val|
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
class PredicateFailureException < Exception
end

class Future(T)
  getter error
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
    @succeeded = nil
    @failed = nil
    @error = nil
    @value = nil
    @blocked_on_this = 0
    @on_failure = [] of Exception+ -> Void
    @on_success = [] of T -> Void
    @on_complete = [] of Future(T) -> Void
    @completion_channel = UnbufferedChannel(Int32).new
    @block = block
    @process = [->(v : T){v}]
    execute()
  end

  # Returns a Future with the function applied to 
  # the result
  def map(&block : T->U)
    Future(U).new @execution_context, do
      val = self.get
      if val
        return block.call(val as T)
      else
        raise self.error as Exception
      end
    end
  end

  # Returns a new future that succeeds if current
  # future succeeds and it's value matches the given
  # predicate
  def select(&block : T -> Bool)
    Future(T).new @execution_context, do
      val = self.get
      if val && block.call(val as T)
        return val
      else
        raise PredicateFailureException.new "Future select predicate failed on value #{val}"
      end
    end
  end

  # Register a callback to be called when the Future
  # succeeds. The callback is called with the value of
  # the future
  def onSuccess(&block : T -> _)
    @on_success << block
    if(@succeeded)
      @execution_context.execute do
        block.call(@value as T)
      end
    end
  end

  # Register a callback to be called when the Future
  # fails
  def onFailure(&block : Exception+ -> _)
    @on_failure << block
    if(@failed)
      @execution_context.execute do
        block.call(@error as Exception)
      end
    end
  end

  # Register a callback to be called when the Future
  # completes. The callback will be called with the
  # current instance on completion
  def onComplete(&block : Future(T) -> _)
    @on_complete << block
    if @completed
      @execution_context.execute do
        if @succeeded
          block.call(self)
        else
          block.call(self)
        end
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
  # nil if still processing
  def succeeded?
    return @succeeded
  end

  # Returns true if processing failed.
  # nil if still processing
  def failed?
    return @failed
  end

  # Blocks untill future to complete and returns
  # the value. Returns nil if failure occurs. Returns the
  # value if already complete
  def get
    if @completed
      @value
    else
      @blocked_on_this += 1
      @completion_channel.receive
      @value
    end
  end

  private def execute()
    @execution_context.execute do
      begin
        @value = @block.call
        # @process.each do |p|
        #   @value = p.call(@value as T)
        # end
        @succeeded = true
        @failed = false
        @on_success.each do |callback|
          @execution_context.execute do 
            callback.call(@value as T)
          end
        end
      rescue e
        @failed = true
        @succeeded = false
        @error = e
        @execution_context.execute do
          @on_failure.each do |callback|
            callback.call(e)
          end
        end
      ensure
        @completed = true
        @on_complete.each do |callback|
        @execution_context.execute do
            if @succeeded
              callback.call(self)
            else
              callback.call(self)
            end
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