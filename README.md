# Futures for Crystal
Futures provide a nice way to reason about performing many operations in parallel– in an efficient and non-blocking way. The idea is simple, a Future is a sort of a placeholder object that you can create for a result that does not yet exist. Generally, the result of the Future is computed concurrently and can be later collected. Composing concurrent tasks in this way tends to result in faster, asynchronous, non-blocking parallel code.

** Source : http://docs.scala-lang.org/overviews/core/futures.html

## Usage
```crystal
require "futures"
include Futures

# Create a new future
a = Future.new do
  someTimeConsumingOperation()
end

# Register a callback on successful operation
a.on_success do |val|
  doSomethingWithResult val
end
a.on_failure do |err|
  raise err
end

# Or handle both cases in one callback
a.on_complete do |result|
  try = result.get
  case try
  when Success
    puts try.get
  when Failure
    raise try.error
  end
end

# Or block until future completes
val = a.get

# compose new Futures from existing ones
b = a.map do |val|
  "String : " + val
end

b.get
```
### Sequencing
Future implements [crz](https://github.com/dhruvrajvanshi/crz) ```Monad``` interface
which means you can call bind on it to sequence multiple actions.
```crystal
def get_first_value
  Future.new do
    # get a value from network
    ...
  end
end

def get_second_value(first_value)
  Future.new do
    # get another value based on 
    # the first value
    ...
  end
end

f = get_first_value.bind do |first_value|
  get_second_value(first_value)
end

f.get # => second value
```

In case of multiple actions in sequence, nested binds can become
tedious and error prone. Use the crz ```mdo``` macro to flatten
nested binds
```crystal
mdo({
  first <= get_first_value,
  second <= get_second_value(first),
  third <= get_third_value(first, second),
  Future.of(third)
})
```
Make sure the last line of mdo is wrapped in a future using 
Future.of or ```Future.new { value }```.

Note that ```<=``` only works on Futures not on regular values 
i.e. ```get_first_value```, ```get_second_value```, ```get_third_value``` 
should return Futures.

You can make normal assignments from regular values inside mdo blocks too.
```crystal
mdo({
  x <= some_async_op,
  a = x + 23,
  ...
})
```

## Documentation
[Link](http://dhruvrajvanshi.github.io/crystal-futures/)
