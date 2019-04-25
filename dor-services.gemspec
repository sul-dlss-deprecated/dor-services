# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)
require 'dor/version'

# rubocop:disable Metrics/BlockLength
Gem::Specification.new do |s|
  s.name        = 'dor-services'
  s.version     = Dor::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Michael Klein', 'Willy Mene', 'Chris Fitzpatrick', 'Richard Anderson', 'Renzo Sanchez-Silva', 'Joseph Atzberger', 'Johnathan Martin']
  s.email       = ['mbklein@stanford.edu']
  s.summary     = 'Ruby implmentation of DOR services used by the SULAIR Digital Library'
  s.description = 'Contains classes to register objects and initialize workflows'
  s.licenses    = ['ALv2', 'Stanford University']
  s.homepage    = 'http://github.com/sul-dlss/dor-services'
  s.required_rubygems_version = '>= 1.3.6'

  # Runtime dependencies
  s.add_dependency 'active-fedora', '>= 8.7.0', '< 9'
  s.add_dependency 'activesupport', '~> 5.1'
  s.add_dependency 'confstruct', '~> 0.2.7'
  s.add_dependency 'deprecation', '~> 0'
  s.add_dependency 'dor-services-client', '~> 1.5'
  s.add_dependency 'equivalent-xml', '~> 0.5', '>= 0.5.1' # 5.0 insufficient
  s.add_dependency 'json', '>= 1.8.1'
  s.add_dependency 'nokogiri', '~> 1.6'
  s.add_dependency 'om', '~> 3.0'
  s.add_dependency 'rdf', '~> 1.1', '>= 1.1.7'
  s.add_dependency 'rest-client', '>= 1.7', '< 3'
  s.add_dependency 'retries', '~> 0.0.5' # used by the release tag service
  s.add_dependency 'rsolr', '>= 1.0.3', '< 3'
  s.add_dependency 'ruby-cache', '~> 0.3.0'
  s.add_dependency 'rubydora', '~> 2.1'
  s.add_dependency 'solrizer', '~> 3.0'
  s.add_dependency 'systemu', '~> 2.6'

  # Stanford dependencies
  s.add_dependency 'dor-rights-auth', '~> 1.0', '>= 1.2.0'
  s.add_dependency 'dor-workflow-client', '~> 3.0'
  s.add_dependency 'druid-tools', '>= 0.4.1'
  s.add_dependency 'moab-versioning', '~> 4.0'
  s.add_dependency 'stanford-mods', '>= 2.3.1'
  s.add_dependency 'stanford-mods-normalizer', '~> 0.1'

  # Bundler will install these gems too if you've checked out dor-services source from git and run 'bundle install'
  # It will not add these as dependencies if you require dor-services for other projects
  s.add_development_dependency 'coveralls'
  s.add_development_dependency 'jhove-service', '>= 1.1.1'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rake', '>= 10'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'rspec', '~> 3.1'
  s.add_development_dependency 'rubocop', '~> 0.65.0'
  s.add_development_dependency 'rubocop-rspec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'yard'

  s.files        = Dir.glob('lib/**/*') + Dir.glob('config/**/*') + Dir.glob('bin/*')
  s.bindir       = 'bin'
  s.require_path = 'lib'
end
# rubocop:enable Metrics/BlockLength
