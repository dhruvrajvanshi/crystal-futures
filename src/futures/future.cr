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

class Future(T)
  getter error

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
    @on_failure = [] of Exception+ -> Void
    @on_success = [] of T -> Void
    @on_complete = [] of (Exception+ | T) -> Void
    @completion_channel = UnbufferedChannel(Int32).new
    @block = block
    @process = [->(v : T){v}]
    execute()
  end

  # Returns a Future with the function applied to 
  # the result
  def map(&block : T->U)
    Future(U).new @execution_context, do
      # block.call (self.get as T)
      v = self.get
      case v
      when T
        return block.call(v)
      when Exception
        raise v
      end
    end
  end

  # Register a callback to be called when the Future
  # succeeds. The callback is called with the value of
  # the future
  def onSuccess(&block : T -> _)
    @on_success << block
    if(@succeeded)
      block.call(@value as T)
    end
  end

  # Register a callback to be called when the Future
  # fails
  def onFailure(&block : Exception+ -> _)
    @on_failure << block
    if(@failed)
      block.call(@error as Exception)
    end
  end

  # Register a callback to be called when the Future
  # completes. May be called with the result or the
  # exception depending on success
  def onComplete(&block : (Exception+ | T) -> _)
    @on_complete << block
    if @completed
      if @succeeded
        block.call(@value as T)
      else
        block.call(@error as Exception)
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
      @completion_channel.receive
      unless @value
        raise @error as Exception
      end
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
              callback.call(@value as T)
            else
              callback.call(@error as Exception)
            end
          end
        end
        @completion_channel.send(0)
        @completion_channel.close
      end
    end
  end
end
