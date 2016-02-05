module Futures
  # Represents optional value. Instances of `Option` are either an
  # instance of `Some` or `None`.
  abstract class Option(T)
    abstract def get
    abstract def empty?
  end

  class Some(T) < Option(T)
    def initialize(@value : T)
    end

    def get
      @value
    end

    def empty?
      false
    end
  end

  class None(T) < Option(T)
    def initialize
    end

    def get
      raise NoSuchElementException.new
    end

    def empty?
      true
    end
  end
end
