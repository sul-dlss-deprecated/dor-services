# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
  
Gem::Specification.new do |s|
  s.name        = "dor-services"
  s.version     = "2.3.1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Michael Klein","Willy Mene","Chris Fitzpatrick","Richard Anderson"]
  s.email       = ["mbklein@stanford.edu"]
  s.summary     = "Ruby implmentation of DOR services used by the SULAIR Digital Library"
  s.description = "Contains classes to register objects and initialize workflows"
 
  s.required_rubygems_version = ">= 1.3.6"
  
  # Runtime dependencies
  s.add_dependency "active-fedora", ">=1.2.6"
  s.add_dependency "solr-ruby", ">=0.0.8"
  s.add_dependency "nokogiri", ">=1.4.3.1"
  s.add_dependency "om", ">=1.2.0"
  s.add_dependency "rest-client"
  s.add_dependency "validatable"
  s.add_dependency "uuidtools"
  s.add_dependency "json"
  s.add_dependency "ruby-cache"
  s.add_dependency "mod-cons", ">=0.2.0"
  s.add_dependency "systemu"
  s.add_dependency "lyber-utils"
  s.add_dependency "ruby-graphviz"
  
  # Bundler will install these gems too if you've checked out dor-services source from git and run 'bundle install'
  # It will not add these as dependencies if you require dor-services for other projects
  s.add_development_dependency "equivalent-xml", ">=0.2.2"
  s.add_development_dependency "fakeweb"
  s.add_development_dependency "haml"
  s.add_development_dependency "jhove-service"
  s.add_development_dependency "lyberteam-devel", ">=0.4.1"
  s.add_development_dependency "rake", ">=0.8.7"
  s.add_development_dependency "rcov"
  s.add_development_dependency "rdoc"
  s.add_development_dependency "rspec", "< 2.0" # We're not ready to upgrade to rspec 2
  s.add_development_dependency "ruby-debug"
  s.add_development_dependency "yard"
 
  s.files        = Dir.glob("lib/**/*")
  s.require_path = 'lib'
end