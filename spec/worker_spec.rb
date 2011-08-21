require "spec_helper"

describe ThreadStorm::Worker do
  before(:each) do
    @queue  = ThreadStorm::Queue.new(2)
    @comm   = ThreadStorm::WorkerComm.new(2)
    @worker = described_class.new(@queue, @comm)
  end

  context "calling #new with a queue and a comm" do
    it "should not return until its thread is running" do
      @worker.thread.should be_alive
    end
  end

  it "should pop executions off the queue and execute them" do
    atc = Atc.new
    mock(execution = Object.new).execute do
      atc.signal(1)
    end
    @queue.enqueue(execution)
    atc.wait(1, 0.1).should be_true
  end

  it "its thread should die if a nil is popped off the queue" do
    @worker.thread.should be_alive
    @queue.enqueue(nil)
    @worker.thread.join(0.1).should_not be_nil
  end

end
