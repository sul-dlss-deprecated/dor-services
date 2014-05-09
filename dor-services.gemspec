# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require 'dor/version'

Gem::Specification.new do |s|
  s.name        = "dor-services"
  s.version     = Dor::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Michael Klein","Willy Mene","Chris Fitzpatrick","Richard Anderson","Renzo Sanchez-Silva"]
  s.email       = ["mbklein@stanford.edu"]
  s.summary     = "Ruby implmentation of DOR services used by the SULAIR Digital Library"
  s.description = "Contains classes to register objects and initialize workflows"
  s.executables = ["dor-indexer","dor-indexerd"]

  s.required_rubygems_version = ">= 1.3.6"

  # Runtime dependencies
  s.add_dependency 'active-fedora', '~> 5.7.1'
  s.add_dependency 'activesupport', '>= 3.2.16'
  s.add_dependency 'confstruct', '~> 0.2.2'
  s.add_dependency 'equivalent-xml', '~> 0.2.2'
  s.add_dependency 'json', '~> 1.8.1'
  s.add_dependency 'net-sftp', '~> 2.1.2'
  s.add_dependency 'net-ssh', '~> 2.7.0'
  s.add_dependency 'nokogiri', '~> 1.6.0'
  s.add_dependency 'om', '~> 1.8.0'
  s.add_dependency 'progressbar', '~> 0.21.0'
  s.add_dependency 'rdf', '~> 1.0.9.0' # 1.0.10 breaks
  s.add_dependency 'rest-client', '~> 1.6.7'
  s.add_dependency 'rsolr-ext', '~> 1.0.3'
  s.add_dependency 'ruby-cache', '~> 0.3.0'
  s.add_dependency 'ruby-graphviz', '~> 1.0.9'
  s.add_dependency 'rubydora', '~> 1.6.5'
  s.add_dependency 'solrizer', '~> 2.0'
  s.add_dependency 'systemu', '~> 2.6.0'
  s.add_dependency 'uuidtools', '~> 2.1.4'
  s.add_dependency 'validatable', '~> 1.6.7'

  # Stanford dependencies
  s.add_dependency 'dor-workflow-service', '~> 1.5'
  s.add_dependency 'druid-tools', '~> 0.3.0'
  s.add_dependency 'lyber-utils', '~> 0.1.2'
  s.add_dependency 'moab-versioning', '1.3.1' # 1.3.2 fails
  s.add_dependency 'stanford-mods', '~> 0.0.14'

  # Bundler will install these gems too if you've checked out dor-services source from git and run 'bundle install'
  # It will not add these as dependencies if you require dor-services for other projects
  s.add_development_dependency 'fakeweb', '~> 1.3.0'
  s.add_development_dependency 'haml', '~> 4.0.4'
  s.add_development_dependency 'jhove-service', '~> 1.0.1'
  s.add_development_dependency 'rake', '~> 0.8.7'
  s.add_development_dependency 'rdoc', '~> 4.0.1'
  s.add_development_dependency 'rspec', '~> 2.14.1'
  s.add_development_dependency 'yard', '~> 0.8.7'

  s.files        = Dir.glob("lib/**/*") + Dir.glob("config/**/*") + Dir.glob('bin/*')
  s.bindir       = 'bin'
  s.require_path = 'lib'
end
