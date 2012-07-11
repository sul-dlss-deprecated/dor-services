$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'bundler/setup'
require 'spec'
require 'spec/autorun'

require 'rubygems'
require 'rake'
require 'dor-services'
#require 'ruby-debug'
require 'foxml_helper'
require 'equivalent-xml'
require 'fakeweb'

ActiveFedora.logger = Logger.new(StringIO.new)

module Dor::SpecHelpers
  def stub_config
    @fixture_dir = fixture_dir = File.join(File.dirname(__FILE__),"fixtures")
    Dor::Config.push! do
      suri.mint_ids false
      gsearch do
        url "http://solr.edu/gsearch"
        rest_url "http://fedora.edu/gsearch/rest"
      end
      solrizer.url "http://solr.edu/solrizer"
      fedora.url "http://fedora.edu/fedora"
      stacks.local_workspace_root File.join(fixture_dir, "workspace")
      sdr.local_workspace_root File.join(fixture_dir, "workspace")
      sdr.local_export_home File.join(fixture_dir, "export")
    end

    Rails.stub_chain(:logger, :error)
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
end

Spec::Runner.configure do |config|
  config.include Dor::SpecHelpers
end

def catch_stdio
  old_handles = [$stdout.dup, $stderr.dup]
  begin
    $stdout.reopen(File.new('/dev/null','w'))
    $stderr.reopen(File.new('/dev/null','w'))
    yield
  ensure
    $stdout.reopen(IO.new(old_handles[0].fileno,'w'))
    $stderr.reopen(IO.new(old_handles[1].fileno,'w'))
  end
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

Rails = Object.new unless defined? Rails

require 'dor_config'
