require "spec_helper"

describe ThreadStorm::Queue do

  before(:each){ @queue = ThreadStorm::Queue.new(2) }

  context "calling #enqueue" do
    it "should put an item on the queue" do
      @queue.enqueue(1)
      @queue.array.should == [1]
    end
    it "should never block" do
      5.times{ |i| @queue.enqueue(i) }
      @queue.array.should == [0, 1, 2, 3, 4]
    end
    it "should notify another thread waiting on #dequeue" do
      atc = Atc.new(:timeout => 0.01)
      item = nil
      thread = Thread.new{ atc.signal(1); item = @queue.dequeue; atc.signal(2) }
      atc.wait(1).should be_true
      atc.wait(2).should be_false
      @queue.enqueue(:thing)
      atc.wait(2).should be_true
      item.should == :thing
    end
  end

  context "calling #dequeue" do
    it "should remove and return an item from the queue" do
      @queue.array << "something"
      @queue.dequeue.should == "something"
      @queue.array.should == []
    end
    it "should block if the queue is empty" do
      begin
        @queue.dequeue
      rescue Exception => e
        e.class.name.should == "fatal"
        e.message.should == "deadlock detected"
      end
    end
  end

  context "calling #shutdown" do
    it "should empty the queue then fill it with nils" do
      5.times{ |i| @queue.enqueue(i) }
      @queue.shutdown
      2.times{ @queue.dequeue.should be_nil }
      @queue.array.should be_empty
    end
  end

end
