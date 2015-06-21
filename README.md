# Futures for Crystal
Futures provide a nice way to reason about performing many operations in parallel– in an efficient and non-blocking way. The idea is simple, a Future is a sort of a placeholder object that you can create for a result that does not yet exist. Generally, the result of the Future is computed concurrently and can be later collected. Composing concurrent tasks in this way tends to result in faster, asynchronous, non-blocking parallel code.

** Source : http://docs.scala-lang.org/overviews/core/futures.html

## Usage
```crystal
require "./src/futures"
include Futures

# Create a new future
a = Future.new do
  someTimeConsumingOperation()
end

# Register a callback on successful operation
a.onSuccess do |val|
  doSomethingWithResult val
end
a.onError do |err|
  raise err
end

# Or handle both cases in one callback
# (assuming future returns a String)
a.onComplete do |x|
  case x
  when String
    puts x
  when Exception
    raise x
  end
end

# Or block untill future completes
val = a.get

# compose new Futures from existing ones
b = a.map do |val|
  "String : " + val
end

b.get
```

## Documentation
```
git clone https://github.com/dhruvrajvanshi/crystal-futures
cd crystal-futures
crystal docs
```
Documentation will be in the crystal-futures/docs folder
