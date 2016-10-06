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
  end

end

