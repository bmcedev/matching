# encoding: utf-8

require 'rubygems'
require 'bundler'
require 'rspec/core/rake_task'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "matching"
  gem.homepage = "http://github.com/btedev/matching"
  gem.license = ""
  gem.summary = "Dataset matching engine"
  gem.description = ""
  gem.email = "barrye@gmail.com"
  gem.authors = ["Barry Ezell"]
  # dependencies defined in Gemfile

  gem.files.exclude 'db/**/*'
end

#Jeweler::RubygemsDotOrgTasks.new

desc "Run all specs"
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = ["--color"]
  spec.pattern = 'spec/**/*_spec.rb'
end

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "matching #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
