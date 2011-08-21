require "spec_helper"

shared_context "executed executions" do
  before(:all) do
    @success_exec = described_class.new :default_value => :one
    @failure_exec = described_class.new :default_value => :two
    @timeout_exec = described_class.new :default_value => :three, :timeout => 0.01
    @success_exec.define("hello"){ |arg| @greeting = arg; "won" }
    @failure_exec.define{ raise "oops" }
    @timeout_exec.define{ sleep }
    @success_exec.execute
    @failure_exec.execute
    @timeout_exec.execute
  end
end

describe ThreadStorm::Execution do
  before(:each){ @atc = ATC.new }

  context "calling #new" do
    it "should return an execution in the initialized state" do
      described_class.new.should be_initialized
    end
    context "with no arguments" do
      it "should inherit ThreadStorm's options" do
        exec = described_class.new
        exec.options.should == ThreadStorm.options
      end
    end
    context "with an options hash" do
      it "should merge over ThreadStorm's options" do
        exec = described_class.new :timeout => 1
        exec.options.should == ThreadStorm.options.merge(:timeout => 1)
      end
    end
    context "with a block" do
      it "should define the execution" do
        exec = described_class.new(:blah){ |arg| arg }
        exec.args.should == [:blah]
        exec.block.should_not be_nil
      end
    end
  end

  context "calling #define" do
    before(:all) do
      @exec = described_class.new
      @exec.define(:one, :two){ true }
    end
    it "should set args and block" do
      @exec.args.should == [:one, :two]
      @exec.block.should_not be_nil
    end
  end

  context "calling #state" do
    before(:all){ @exec = described_class.new }
    it "should return a constant" do
      @exec.state.should == ThreadStorm::Execution::STATE_INITIALIZED
    end
    it "or a symbol" do
      @exec.state(:sym).should == :initialized
    end
  end

  context "calling #state?" do
    before(:all){ @exec = described_class.new }
    it "should ask what state the execution is in" do
      @exec.should be_state(:initialized)
    end
  end

  context "calling #initialized?" do
    before(:all){ @exec = described_class.new }
    it "should return true if the execution is initialized" do
      @exec.should be_initialized
    end
  end

  context "calling #queued?" do
    it "should return true if the execution is queued" do
      ThreadStorm.new :size => 1 do |storm|
        exec1 = storm.execute{ @atc.signal(1); @atc.wait(2) }
        exec2 = storm.execute{ nil }
        @atc.wait(1)
        exec2.should be_queued
        @atc.signal(2)
      end
    end
  end

  context "calling #started?" do
    it "should return true if the execution is started" do
      ThreadStorm.new :size => 1 do |storm|
        exec = storm.execute{ @atc.signal(1); @atc.wait(2) }
        @atc.wait(1)
        exec.should be_started
        @atc.signal(2)
      end
    end
  end

  context "calling #finished?" do
    it "should return true if the execution is finished" do
      exec = nil
      ThreadStorm.new :size => 1 do |storm|
        exec = storm.execute{ nil }
      end
      exec.should be_finished
    end
  end

  context "calling #state_at" do
    it "should return when the execution entered a given state" do
      Timecop.freeze do
        time = Time.now
        exec = described_class.new
        exec.state_at(ThreadStorm::Execution::STATE_INITIALIZED).should == time
      end
    end
    it "should work with symbols" do
      Timecop.freeze do
        time = Time.now
        exec = described_class.new
        exec.state_at(:initialized).should == time
      end
    end
    it "should return nil if the execution hasn't entered that state yet" do
      exec = described_class.new
      exec.state_at(:queued).should be_nil
    end
  end

  # Shared context for *_at methods.
  context "(state_at convenience methods)" do
    before(:all) do
      Timecop.freeze do
        ThreadStorm.new do |storm|
          @time = Time.now
          @exec = storm.execute{ true }
        end
      end
    end
    context "calling #initialized_at" do
      it "should return when the execution was initialized" do
        @exec.initialized_at.should == @time
      end
    end
    context "calling #queued_at" do
      it "should return when the execution was queued" do
        @exec.queued_at.should == @time
      end
    end
    context "calling #started_at" do
      it "should return when the execution was started" do
        @exec.started_at.should == @time
      end
    end
    context "calling #finished_at" do
      it "should return when the execution was finished" do
        @exec.finished_at.should == @time
      end
    end
  end

  context "calling #duration" do
    before(:all) do
      Timecop.freeze
      ThreadStorm.new :size => 1 do |storm|
        atc = ATC.new
        storm.execute{ atc.signal(1); atc.wait(2) }
        @exec = described_class.new{ atc.signal(3); atc.wait(4) }
        atc.wait(1)
        Timecop.freeze(1)
        storm.execute(@exec)
        Timecop.freeze(2)
        atc.signal(2)
        atc.wait(3)
        Timecop.freeze(3)
        atc.signal(4)
        @exec.join
        Timecop.freeze(4)
      end
    end
    after(:all){ Timecop.return }
    it "should return how long an execution was in a given state" do
      @exec.duration(:initialized).should == 1
      @exec.duration(:queued).should      == 2
      @exec.duration(:started).should     == 3
      @exec.duration(:finished).should    == 4
    end
    it "should return how long an execution has been in a given state" do
      exec = described_class.new
      exec.duration(:initialized).should == 0
      Timecop.freeze(1)
      exec.duration(:initialized).should == 1
      Timecop.freeze(1)
      exec.duration(:initialized).should == 2
      Timecop.freeze(-2) # So the next example works.
    end
    it "should work with constants" do
      @exec.duration(ThreadStorm::Execution::STATE_INITIALIZED).should == 1
      @exec.duration(ThreadStorm::Execution::STATE_QUEUED).should      == 2
      @exec.duration(ThreadStorm::Execution::STATE_STARTED).should     == 3
      @exec.duration(ThreadStorm::Execution::STATE_FINISHED).should    == 4
    end
  end

  context "calling #queued!" do
    before(:all){ @exec = described_class.new; @exec.queued! }
    it "should put the execution in the queued state" do
      @exec.should be_queued
    end
    it "it should disallow changing the options" do
      expect{ @exec.options[:timeout] = 2 }.to raise_error(RuntimeError)
    end
  end

  context "calling #execute" do
    include_context "executed executions"
    it "should evaluate the block, yielding the given args" do
      @greeting.should == "hello"
      @success_exec.exception.should be_nil
      @success_exec.value.should == "won"
    end
    it "should handle errors" do
      @failure_exec.exception.should be_a(RuntimeError)
      @failure_exec.exception.message.should == "oops"
    end
    it "should handle timeouts" do
      @timeout_exec.exception.should be_a(Timeout::Error)
      @timeout_exec.exception.message.should == "execution expired"
    end
    it "should always put the execution into the finished state" do
      @success_exec.should be_finished
      @failure_exec.should be_finished
      @timeout_exec.should be_finished
    end
  end

  context "calling #success?" do
    include_context "executed executions"
    it "should return true for successful executions" do
      @success_exec.should be_success
    end
    it "should not return true for failed executions" do
      @failure_exec.should_not be_success
    end
    it "should not return true for timed out executions" do
      @timeout_exec.should_not be_success
    end
  end

  context "calling #failure?" do
    include_context "executed executions"
    it "should return true for failed executions" do
      @failure_exec.should be_failure
    end
    it "should not return true for successful executions" do
      @success_exec.should_not be_failure
    end
    it "should not return true for timed out executions" do
      @timeout_exec.should_not be_failure
    end
  end

  context "calling #timeout?" do
    include_context "executed executions"
    it "should return true for timed out executions" do
      @timeout_exec.should be_timeout
    end
    it "should not return true for successful executions" do
      @success_exec.should_not be_timeout
    end
    it "should not return true for failed executions" do
      @failure_exec.should_not be_timeout
    end
  end

  context "calling #join" do
    include_context "executed executions"
    it "should wait for the execution to finish" do
      @success_exec.join.should be_true
    end
    it "should reraise exceptions" do
      expect{ @failure_exec.join }.to raise_error(RuntimeError)
    end
    it "should not reraise exception if :reraise => false" do
      mock(@failure_exec).options{ { :reraise => false } }
      expect{ @failure_exec.join }.to_not raise_error(RuntimeError)
    end
    it "should not reraise timeout errors" do
      expect{ @timeout_exec.join }.to_not raise_error(Timeout::Error)
    end
  end

  context "calling #value" do
    include_context "executed executions"
    it "should return the value of a successful execution" do
      @success_exec.value.should == "won"
    end
    it "should return the default value of a failed execution when :reraise => false" do
      options = @failure_exec.options.merge(:reraise => false)
      mock(@failure_exec).options{ options }.twice
      @failure_exec.value.should == :two
    end
    it "should return the default value of a timed out execution when :reraise => false" do
      options = @timeout_exec.options.merge(:reraise => false)
      mock(@timeout_exec).options{ options }
      @timeout_exec.value.should == :three
    end
  end

  context "with callbacks" do
    before(:all) do
      Timecop.freeze
      @time = Time.now
      initialized_callback = proc do |exec|
        exec.instance_eval do
          @timings = []
          @timings << Time.now
        end
      end
      queued_callback = proc{ |exec| exec.instance_eval{ @timings << Time.now } }
      started_callback = proc{ |exec| exec.instance_eval{ @timings << Time.now } }
      finished_callback = proc{ |exec| exec.instance_eval{ @timings << Time.now } }
      exec = described_class.new :initialized_callback => initialized_callback,
                                  :queued_callback => queued_callback,
                                  :started_callback => started_callback,
                                  :finished_callback => finished_callback
      atc = ATC.new
      ThreadStorm.new(:size => 1) do |storm|
        storm.execute{ atc.signal(1); atc.wait(2) }
        atc.wait(1)
        Timecop.freeze(1)
        exec.define{ atc.signal(3); atc.wait(4) }
        storm.execute(exec)
        Timecop.freeze(1)
        atc.signal(2)
        atc.wait(3)
        Timecop.freeze(1)
        atc.signal(4)
      end
      @timings = exec.instance_variable_get(:@timings)
      Timecop.return
    end
    it "should call initialized_callback when initialized" do
      @timings[0].should == @time
    end
    it "should call queued_callback when queued" do
      @timings[1].should == @time + 1
    end
    it "should call started_callback when started" do
      @timings[2].should == @time + 2
    end
    it "should call finished_callback when finished" do
      @timings[3].should == @time + 3
    end
    context "with an exception in a callback" do
      before(:all){ @exec = described_class.new :initialized_callback => proc{ raise "oops" } }
      context "calling #callback_exception?" do
        it "should return true" do
          @exec.should be_callback_exception
        end
        it "should return true if given a state that had a callback exception" do
          @exec.should be_callback_exception(:initialized)
        end
        it "should return false if given a state that didn't have a callback exception" do
          @exec.should_not be_callback_exception(:started)
        end
      end
      context "calling #callback_exception" do
        it "should return all callback exceptions as a hash" do
          @exec.callback_exception.should be_a(Hash)
          e = @exec.callback_exception[:initialized]
          e.should be_a(RuntimeError)
          e.message.should == "oops"
        end
        it "with a state should return the exception for that just state" do
          e = @exec.callback_exception(:initialized)
          e.should be_a(RuntimeError)
          e.message.should == "oops"
        end
      end
    end # context "with an exception in a callback"
  end # context "with callbacks"

end
