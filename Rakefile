require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rake/gempackagetask'

CLEAN << 'pkg' << 'doc' << 'test/db' << '*.log' << '*.orig'

desc "Run all tests by default"
task :default => [:basic_tests, :ar_tests]

desc 'Run the unit tests in test directory'
Rake::TestTask.new('basic_tests') do |t|
  t.libs << 'test'
  t.pattern = 'test/*_test.rb'
  t.verbose = true
end

desc 'Run the ActiveRecords tests with Ackbar'
Rake::TestTask.new('ar_tests') do |t|
  t.libs << 'test'
  t.pattern = 'ar_base_tests_runner.rb'
  t.verbose = true
end

require 'kirbybase_adapter'
ackbar_spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'ackbar'
  s.version = ActiveRecord::ConnectionAdapters::KirbyBaseAdapter::VERSION
  s.summary = "ActiveRecord KirbyBase Adapter"
  s.description = %q{An adapter for Rails::ActiveRecord ORM to the KirbyBase pure-ruby DBMS}

  s.author = "Assaph Mehr"
  s.email = "assaph@gmail.com"
  s.rubyforge_project = 'ackbar'
  s.homepage = 'http://ackbar.rubyforge.org'

  s.has_rdoc = true
  s.extra_rdoc_files = %W{README CHANGELOG TODO FAQ}
  s.rdoc_options << '--title' << 'Ackbar -- ActiveRecord Adapter for KirbyBase' <<
                    '--main'  << 'README' <<
                    '--exclude' << 'test' <<
                    '--line-numbers'
  
  s.add_dependency('KirbyBase', '= 2.5.2')
  s.add_dependency('activerecord', '= 1.13.2')

  s.require_path = '.'

  s.files =  FileList.new %W[
    kirbybase_adapter.rb
    Rakefile
    CHANGELOG
    FAQ
    README
    TODO
    test/00*.rb
    test/ar_base_tests_runner.rb
    test/ar_model_adaptation.rb
    test/connection.rb
    test/create_dbs_for_ar_tests.rb
    test/kb_*_test.rb
    test/model.rb
    test/schema.rb
    test/test_helper.rb
    test/fixtures/*.yml
  ]
end

desc 'Package as gem & zip'
Rake::GemPackageTask.new(ackbar_spec) do |p|
  p.gem_spec = ackbar_spec
  p.need_tar = true
  p.need_zip = true
end

