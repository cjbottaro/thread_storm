require "spec_helper"

describe ThreadStorm::WorkerComm do
  before(:each){ @comm = described_class.new(2) }

  context "calling #wait_until_free_worker" do
    it "should not block if a worker is free" do
      atc = Atc.new(:timeout => 0.01)
      Thread.new do
        2.times{ @comm.wait_until_free_worker }
        atc.signal(1)
      end
      atc.wait(1).should be_true
    end
    it "should block if all workers are busy" do
      atc = Atc.new(:timeout => 0.01)
      Thread.new do
        3.times{ @comm.wait_until_free_worker }
        atc.signal(1)
      end
      atc.wait(1).should_not be_true
    end
  end

  context "calling #decr_busy_worker" do
    it "should free a worker" do
      atc = Atc.new(:timeout => 0.01)
      Thread.new do
        2.times{ @comm.wait_until_free_worker }
        atc.signal(1); atc.wait(2)
        2.times{ @comm.wait_until_free_worker }
        atc.signal(3)
      end
      atc.wait(1).should be_true
      2.times{ @comm.decr_busy_worker }
      atc.signal(2)
      atc.wait(3).should be_true
    end
    it "should unblock #wait_until_free_worker" do
      atc = Atc.new(:timeout => 0.01)
      Thread.new do
        3.times{ @comm.wait_until_free_worker }
        atc.signal(1)
      end
      atc.wait(1).should_not be_true
      @comm.decr_busy_worker
      atc.wait(1).should be_true
    end
  end

end
