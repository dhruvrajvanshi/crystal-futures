require "./spec_helper"

describe Future do

  describe "#get" do
    it "returns the value from the proc" do
      future = Future.new { "hello world" }
      future.get.should eq("hello world")
    end
  end

  describe "#select" do
    it "returns if the predicate yields a truthy value" do
      future1 = Future.new { "hello world" }
      future2 = future1.select {|v| v == "hello world"}
      future2.get.should eq("hello world")
    end

    it "raises if the predicate yields a falsy value" do
      future1 = Future.new { "hello world" }
      future2 = future1.select {|v| v == "goodbye world"}
      expect_raises { future2.get }
    end
  end

  describe "#filter" do
    it "returns the value if it matches the predicate" do
      future1 = Future.new { "hello world" }
      future2 = future1.filter {|v| v == "hello world"}
      future2.get.should eq("hello world")
    end

    it "raises if the predicate yields a falsy value" do
      future1 = Future.new { "hello world" }
      future2 = future1.filter {|v| v == "goodbye world"}
      expect_raises { future2.get }
    end

    it "implements of" do
      future = Future.of 23
      future.get.should eq 23
    end

    it "implements map" do
      future = Future.of 1
      future.map do |x|
        x + 1
      end.get.should eq 2

      future = Future(Int32).new do
        raise "Error"
      end

      expect_raises do
        future.map {|x| x + 1}
            .get
      end

      future = Future.of 2
      expect_raises do
        future.map {|x| raise "asdf" }
          .get
      end
    end

    it "implements bind" do
      future = Future.of 1
      future.bind do |x|
        Future.of x + 1
      end.get.should eq 2

      future = Future(Int32).new do
        raise "error"
      end

      future1 = future.bind do |x|
        Future.of x + 1
      end

      expect_raises { future1.get }
    end

    it "works with mdo macro" do
      mdo({
        x <= Future.of(1),
        y <= Future.of(x + 1),
        Future.of y + 1
      }).get.should eq 3
    end
  end

end

