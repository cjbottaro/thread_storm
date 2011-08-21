require "spec_helper"

describe ThreadStorm::Queue do

  context "that doesn't block" do
    before(:each){ @queue = described_class.new(1, false) }
    context "calling #enqueue" do
      it "should put an item on the queue" do
        @queue.enqueue("item")
        @queue.array.size.should == 1
        @queue.array.first.should == "item"
      end
      it "should never block" do
        5.times{ |i| @queue.enqueue(i) }
        @queue.array.size.should == 5
      end
    end
    context "calling #dequeue" do
      it "should remove an item from the queue" do
        @queue.array << "something"
        @queue.dequeue.should == "something"
      end
    end
    context "calling #shutdown" do
      it "should fill the queue with nils" do
        @queue = described_class.new(2, false)
        @queue.shutdown
        @queue.array.should == [nil, nil]
      end
    end
  end

end
