require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'dor/services/archiving_workspace_service'

describe Dor::ArchivingWorkspaceService do
  before(:each) { stub_config }
  
  before(:each) do
     @workspace_root = Dor::Config.stacks.local_workspace_root
  end
    
  describe 'archive_workspace_druid_tree' do
    
    before(:each) do
       @druid = "druid:aa111aa1111"
       @druid_tree_path = "#{@workspace_root}/aa/111/aa/1111/aa111aa1111"
       
       #To make sure the directory name is as expected aa111aa1111
       FileUtils.mv(@druid_tree_path+"_v2", @druid_tree_path) if File.exists?(@druid_tree_path+"_v2")
    end
    
    it "should rename the directory tree with the directory not empty" do
       Dor::ArchivingWorkspaceService.archive_workspace_druid_tree(@druid,@workspace_root)

       File.exists?("#{@druid_tree_path}_v2").should eq true
       File.exists?(@druid_tree_path).should eq false
    end
    
    it "should throw an error if the directory doesn't exist" do
       not_existent_druid = "druid:xx111xx1111"      
       expect{ Dor::ArchivingWorkspaceService.archive_workspace_druid_tree(not_existent_druid,@workspace_root) }.to raise_error
    end
    
    after(:each) do
      #To reset the environment to its original format
      FileUtils.mv(@druid_tree_path+"_v2", @druid_tree_path) if File.exists?(@druid_tree_path+"_v2")
    end
    
  end
end