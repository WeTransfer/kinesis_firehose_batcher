# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
require_relative 'lib/kinesis_firehose_batcher'

Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.version = KinesisFirehoseBatcher::VERSION
  gem.name = "kinesis_firehose_batcher"
  gem.homepage = "https://github.com/wetransfer/kinesis_firehose_batcher"
  gem.license = "MIT"
  gem.description = %Q{Sends records to Firehose, automatically honors the limits}
  gem.summary = %Q{Batch-send records to AWS Kinesis Firehose}
  gem.email = "me@julik.nl"
  gem.authors = ["Julik Tarkhanov"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

task :default => :spec
