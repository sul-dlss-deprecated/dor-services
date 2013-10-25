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

  s.add_dependency "active-fedora", "~>6.0"
  s.add_dependency "om"
  s.add_dependency "solrizer", "~> 3.0"
  s.add_dependency "activesupport"
  s.add_dependency "rsolr-ext"
  s.add_dependency "nokogiri", ">= 1.6.0"
  s.add_dependency "confstruct", ">= 0.2.2"
  s.add_dependency "rest-client"
  s.add_dependency "validatable"
  s.add_dependency "uuidtools"
  s.add_dependency "json"
  s.add_dependency "ruby-cache"
  s.add_dependency "systemu"
  s.add_dependency "lyber-utils"
  s.add_dependency "ruby-graphviz"
  s.add_dependency "progressbar"
  s.add_dependency "equivalent-xml", ">=0.2.2"
  s.add_dependency "net-ssh"
  s.add_dependency "net-sftp"
  s.add_dependency "druid-tools", ">=0.2.3"
  s.add_dependency "moab-versioning", ">=1.2.1"
  s.add_dependency "stanford-mods", ">=0.0.14"
  s.add_dependency "dor-workflow-service", "~>1.3"

  # Bundler will install these gems too if you've checked out dor-services source from git and run 'bundle install'
  # It will not add these as dependencies if you require dor-services for other projects
  s.add_development_dependency "fakeweb"
  s.add_development_dependency "haml"
  s.add_development_dependency "jhove-service", ">=1.0.1  "
  s.add_development_dependency "rake", ">=0.8.7"
  s.add_development_dependency "rdoc"
  s.add_development_dependency "rspec", "~> 2.14"
  s.add_development_dependency "yard"

  s.files        = Dir.glob("lib/**/*") + Dir.glob("config/**/*") + Dir.glob('bin/*')
  s.bindir       = 'bin'
  s.require_path = 'lib'
end
