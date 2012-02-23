$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'bundler/setup'
require 'spec'
require 'spec/autorun'

require 'rubygems'
require 'dor-services'
require 'ruby-debug'
require 'foxml_helper'
require 'equivalent-xml'

Spec::Runner.configure do |config|

end

def stub_config
  @fixture_dir = fixture_dir = File.join(File.dirname(__FILE__),"fixtures")
  Dor::Config.push! do
    suri.mint_ids false
    gsearch.url "http://solr.edu"
    fedora.url "http://fedora.edu"
    stacks.local_workspace_root File.join(fixture_dir, "workspace")
    sdr.local_workspace_root File.join(fixture_dir, "workspace")
    sdr.local_export_home File.join(fixture_dir, "export")
  end

  Rails.stub_chain(:logger, :error)
  ActiveFedora::SolrService.register(Dor::Config.gsearch.url)
  ActiveFedora::RubydoraConnection.connect(:url=>Dor::Config.fedora.url)
  ActiveFedora.stub!(:fedora).and_return(stub('frepo').as_null_object)
end

def unstub_config
  Dor::Config.pop!
end

def instantiate_fixture druid, klass = ActiveFedora::Base
  mask = File.join(@fixture_dir,"*_#{druid.sub(/:/,'_')}.xml")
  fname = Dir[mask].first
  return nil if fname.nil?
  item_from_foxml(File.read(fname), klass)
end

def read_fixture fname
  File.read(File.join(@fixture_dir,fname))
end

module Kernel
  # Suppresses warnings within a given block.
  def with_warnings_suppressed
    saved_verbosity = $-v
    $-v = nil
    yield
  ensure
    $-v = saved_verbosity
  end
end

def class_exists?(class_name)
  klass = Module.const_get(class_name)
  return klass.is_a?(Class)
rescue NameError
  return false
end


Rails = Object.new unless defined? Rails
# Rails = Object.new unless(class_exists? 'Rails')

require 'dor_config'
