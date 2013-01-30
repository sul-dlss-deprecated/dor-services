require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class AssembleableItem < ActiveFedora::Base
  include Dor::Assembleable
end

describe Dor::Assembleable do

    before :all do
      @temp_workspace = '/tmp/dor_ws'
      FileUtils.rm_rf(@temp_workspace)

      Dor::Config.push! do |config|
        config.suri.mint_ids false
        config.gsearch.url "http://solr.edu/gsearch"
        config.solrizer.url "http://solr.edu/solrizer"
        config.fedora.url "http://fedora.edu"
        config.stacks.local_workspace_root @temp_workspace
      end

      FileUtils.mkdir_p(@temp_workspace)
    end

    after :all do
      Dor::Config.pop!
      FileUtils.rm_rf(@temp_workspace)
    end

    before(:each) do
      ActiveFedora.stub!(:fedora).and_return(stub('frepo').as_null_object)
    end

  describe "#initialize_workspace" do

    before(:each) do
      @ai = AssembleableItem.new
      @ai.stub!(:pid).and_return('aa123bb7890')
      @druid_path = File.join(@temp_workspace, 'aa', '123', 'bb', '7890', 'aa123bb7890')
      FileUtils.rm_rf(File.join(@temp_workspace, 'aa'))
    end

    it "creates a plain directory in the workspace when passed no params" do
      @ai.initialize_workspace

      File.should be_directory(@druid_path)
      File.should_not be_symlink(@druid_path)
    end

    it "creates a link in the workspace to a passed in source directory" do
      source_dir = '/tmp/content_dir'
      FileUtils.mkdir_p(source_dir)
      @ai.initialize_workspace(source_dir)

      File.should be_symlink(@druid_path)
      File.readlink(@druid_path).should == source_dir
    end

  end
end
