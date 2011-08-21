require "spec_helper"

describe ThreadStorm do
  it "should have global options" do
    ThreadStorm.options.should == ThreadStorm::DEFAULTS
  end

  context "calling #new" do
    it "with options should override the global options" do
      storm = ThreadStorm.new :default_value => "blah"
      storm.options.should == ThreadStorm::DEFAULTS.merge(:default_value => "blah")
    end
    it "should create new threads" do
      count = Thread.list.length
      storm = ThreadStorm.new :size => 10
      Thread.list.length.should == count + 10 # TODO race condition here.
    end
    context "with a block" do
      it "should yield a storm" do
        storm = ThreadStorm.new do |s|
          s.should be_a(ThreadStorm)
        end
      end
      it "should join and shutdown" do
        storm = ThreadStorm.new do |s|
          mock.proxy(s).join
          mock.proxy(s).shutdown
        end
      end
    end
  end

  context "calling #new_execution" do
    before(:all){ @storm = ThreadStorm.new }
    context "without a block" do
      it "should return an execution" do
        @storm.new_execution.should be_a(ThreadStorm::Execution)
      end
      it "should inherit the storm's options (if no arguments given)" do
        execution = @storm.new_execution
        execution.options.should == @storm.options
      end
      it "should merge over the storm's options (if given an options hash)" do
        @storm.options[:default_value].should be_nil
        execution = @storm.new_execution :default_value => "blah"
        @storm.options[:default_value].should be_nil
        execution.options.should == @storm.options.merge(:default_value => "blah")
      end
    end
    context "with a block" do
      it "should return an execution" do
        @storm.new_execution{ nil }.should be_a(ThreadStorm::Execution)
      end
      it "should inherit the storm's options" do
        execution = @storm.new_execution{ nil }
        execution.options.should == @storm.options
      end
      it "should define the execution" do
        execution = @storm.new_execution(1, :one){ nil }
        execution.args.should == [1, :one]
        execution.block.should_not be_nil
      end
    end
  end

  context "calling #run" do
    before(:all){ @storm = ThreadStorm.new }
    it "should yield itself" do
      @storm.run{ |s| s.should be_a(ThreadStorm) }
    end
    it "should join and shutdown" do
      @storm.run do |s|
        mock.proxy(s).join
        mock.proxy(s).shutdown
      end
    end
  end

  context "calling #execute" do
    before(:all){ @storm = ThreadStorm.new :size => 1 }
    it "should add an execution to the executions list" do
      count = @storm.executions.length
      @storm.execute{ nil }.join
      @storm.executions.length.should == count + 1
    end
    context "with a block" do
      before(:all){ @exec = @storm.execute(:hi){ |greeting| "#{greeting} to you" } }
      it "should return an execution with the storm's options" do
        @exec.options.should == @storm.options
      end
      it "should define the execution with the given args and block" do
        @exec.args.should == [:hi]
        @exec.block.should_not be_nil
      end
      it "should execute the execution" do
        @exec.value.should == "hi to you"
      end
    end
    context "with an already defined execution" do
      before(:all) do
        @exec = ThreadStorm::Execution.new{ "goodbye to you" }
        @storm.execute(@exec)
      end
      it "should execute the execution" do
        @exec.value.should == "goodbye to you"
      end
    end
  end

  context "calling #join" do
    before(:all) do
      @storm = ThreadStorm.new
      @storm.execute{ nil }
      @storm.execute{ nil }
    end
    it "should call #join on all its executions" do
      @storm.executions.each{ |exec| mock.proxy(exec).join }
      @storm.join
    end
  end

  context "calling #values" do
    before(:all) do
      @storm = ThreadStorm.new
      @storm.execute{ :one }
      @storm.execute{ :two }
    end
    it "should collect the values of its executions" do
      @storm.values.should == [:one, :two]
    end
  end

  context "calling #shutdown" do
    before(:all) do
      @storm = ThreadStorm.new
    end
    it "should kill all the threads" do
      @storm.threads.each{ |thread| thread.should be_alive } # TODO race condition.
      @storm.shutdown
      @storm.threads.each{ |thread| thread.should_not be_alive }
    end
  end

  context "calling #clear_executions" do
    before(:each) do
      @storm = ThreadStorm.new
      @storm.execute{ :finished }.join
      @storm.execute{ sleep }
    end
    it "should use a block to determine what to clear" do
      @storm.executions.length.should == 2
      @storm.clear_executions{ |exec| exec.finished? }
      @storm.executions.length.should == 1
    end
    it "should use a symbol to determine what to clear" do
      @storm.executions.length.should == 2
      @cleared = @storm.clear_executions(:finished?)
      @storm.executions.length.should == 1
    end
    it "should return the cleared executions" do
      cleared = @storm.clear_executions(:finished?)
      cleared.length.should == 1
      cleared.first.should be_finished
    end
  end

end
