# frozen_string_literal: true

source 'https://rubygems.org'

group :development do
  gem 'pry-byebug'
end

# Dependencies are defined in dor-services.gemspec
gemspec

gem 'active-fedora', ENV['AF_VERSION'] if ENV['AF_VERSION']
gem 'activemodel', ENV['RAILS_VERSION'] if ENV['RAILS_VERSION']

# Due to a possible bundler bug, resolving the dependencies for linkeddata 1.99
# either breaks or takes an incredibly long time. Pinning these dependencies
# seem to make it work.
gem 'ebnf', '1.0.0'
gem 'linkeddata', '~> 1.99'
gem 'rdf', '~> 1.99'
gem 'rdf-microdata', '2.0.2'
gem 'rdf-reasoner', '~> 0.3.0'
gem 'rdf-tabular', '~> 0.3.0'
