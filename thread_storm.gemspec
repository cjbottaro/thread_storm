# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{thread_storm}
  s.version = "0.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Christopher J. Bottaro"]
  s.date = %q{2010-06-14}
  s.description = %q{Simple thread pool with timeouts, default values, error handling, state tracking and unit tests.}
  s.email = %q{cjbottaro@alumni.cs.utexas.edu}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "CHANGELOG",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "lib/thread_storm.rb",
     "lib/thread_storm/active_support.rb",
     "lib/thread_storm/execution.rb",
     "lib/thread_storm/queue.rb",
     "lib/thread_storm/semaphore.rb",
     "lib/thread_storm/worker.rb",
     "test/helper.rb",
     "test/test_thread_storm.rb",
     "thread_storm.gemspec"
  ]
  s.homepage = %q{http://github.com/cjbottaro/thread_storm}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Simple thread pool with a few advanced features.}
  s.test_files = [
    "test/helper.rb",
     "test/test_thread_storm.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

