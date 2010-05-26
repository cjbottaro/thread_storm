# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{thread_pool}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Christopher J. Bottaro"]
  s.date = %q{2010-05-25}
  s.description = %q{Simple thread pool with timeouts, default values, error handling, state tracking and unit tests.}
  s.email = %q{cjbottaro@alumni.cs.utexas.edu}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "lib/thread_pool.rb",
     "lib/thread_pool/active_support.rb",
     "lib/thread_pool/execution.rb",
     "lib/thread_pool/worker.rb",
     "test/helper.rb",
     "test/test_thread_pool.rb"
  ]
  s.homepage = %q{http://github.com/cjbottaro/thread_pool}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{Simple thread pool with a few advanced features.}
  s.test_files = [
    "test/helper.rb",
     "test/test_thread_pool.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

