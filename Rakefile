# frozen_string_literal: true

require 'rubygems'
require 'rake'
require 'bundler'
require 'bundler/gem_tasks'
require 'rubocop/rake_task'

Dir.glob('lib/tasks/*.rake').each { |r| import r }

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  warn e.message
  warn 'Run `bundle install` to install missing gems'
  exit e.status_code
end

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
end

RuboCop::RakeTask.new(:rubocop)

task rcov: [:spec]

task :clean do
  puts 'Cleaning old coverage.data'
  FileUtils.rm('coverage.data') if File.exist? 'coverage.data'
end

task default: %i[rubocop spec doc]
