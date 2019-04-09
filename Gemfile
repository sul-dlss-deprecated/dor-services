# frozen_string_literal: true

source 'https://rubygems.org'

group :development do
  gem 'pry-byebug'
end

# Dependencies are defined in dor-services.gemspec
gemspec

gem 'active-fedora', ENV['AF_VERSION'] if ENV['AF_VERSION']
gem 'activemodel', ENV['RAILS_VERSION'] if ENV['RAILS_VERSION']
