# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)
require 'dor/version'

Gem::Specification.new do |s|
  s.name        = 'dor-services'
  s.version     = Dor::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Michael Klein', 'Willy Mene', 'Chris Fitzpatrick', 'Richard Anderson', 'Renzo Sanchez-Silva', 'Joseph Atzberger', 'Johnathan Martin']
  s.email       = ['mbklein@stanford.edu']
  s.summary     = 'Ruby implmentation of DOR services used by the SULAIR Digital Library'
  s.description = 'Contains classes to register objects and initialize workflows'
  s.licenses    = ['ALv2', 'Stanford University']

  s.required_rubygems_version = '>= 1.3.6'

  # Runtime dependencies
  s.add_dependency 'active-fedora', '~> 6.0'
  s.add_dependency 'activesupport', '>= 3.2.18' # '~> 4.0' #
  s.add_dependency 'confstruct', '~> 0.2.7'
  s.add_dependency 'equivalent-xml', '~> 0.5', '>= 0.5.1' # 5.0 insufficient
  s.add_dependency 'json', '~> 1.8.1'
  s.add_dependency 'net-sftp', '~> 2.1'
  s.add_dependency 'nokogiri', '~> 1.6'
  s.add_dependency 'nokogiri-pretty', '~> 0.1'
  s.add_dependency 'om', '~> 3.0'
  s.add_dependency 'rdf', '~> 1.1.7' # 1.0.10 breaks
  s.add_dependency 'rest-client', '~> 1.7'
  s.add_dependency 'rsolr-ext', '~> 1.0.3'
  s.add_dependency 'ruby-cache', '~> 0.3.0'
  s.add_dependency 'ruby-graphviz'
  s.add_dependency 'rubydora', '~> 1.6.5' # highly sensitive/volatile dependency
  s.add_dependency 'solrizer', '~> 3.0'
  s.add_dependency 'systemu', '~> 2.6'
  s.add_dependency 'uuidtools', '~> 2.1.4'
  # s.add_dependency 'validatable', '~> 1.6.7'
  s.add_dependency 'retries'

  # Stanford dependencies
  s.add_dependency 'dor-workflow-service', '~> 2.0', '>= 2.0.1'
  s.add_dependency 'druid-tools', '~> 0.4', '>= 0.4.1'
  s.add_dependency 'dor-rights-auth', '~> 1.0', '>= 1.0.2'
  s.add_dependency 'lyber-utils', '~> 0.1.2'
  s.add_dependency 'moab-versioning', '~> 2.0'
  s.add_dependency 'modsulator', '~> 0.0.7'
  s.add_dependency 'stanford-mods', '= 1.5.3'  # v1.5.4 changes what sw_genre returns, which breaks test expectations.  TODO: figure out how to keep argo indexed counterparts of searchworks fields in sync w/ current SW behavior.

  # Bundler will install these gems too if you've checked out dor-services source from git and run 'bundle install'
  # It will not add these as dependencies if you require dor-services for other projects
  s.add_development_dependency 'coveralls'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'jhove-service', '~> 1.0.1'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rake', '~> 10.0'
  s.add_development_dependency 'rspec', '~> 3.1'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'vcr'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'yard'

  s.files        = Dir.glob('lib/**/*') + Dir.glob('config/**/*') + Dir.glob('bin/*')
  s.bindir       = 'bin'
  s.require_path = 'lib'
end
