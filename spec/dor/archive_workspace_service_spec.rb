require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'dor/services/archive_workspace_service'

describe Dor::ArchiveWorkspaceService do
  before(:each) { stub_config }
  
  before(:each) do
     @workspace_root = Dor::Config.stacks.local_workspace_root
  end
    
  describe 'archive_workspace_druid_tree' do
    
    before(:each) do
       @druid = "druid:am111am1111"
       @druid_tree_path = "#{@workspace_root}/am/111/am/1111/am111am1111"
      
       @archived_druid = "druid:vr111vr1111"
       @archived_druid_tree_path = "#{@workspace_root}/vr/111/vr/1111/vr111vr1111"

       #To make sure the directory name is as expected am111am1111
       FileUtils.mv(@druid_tree_path+"_v2", @druid_tree_path) if File.exists?(@druid_tree_path+"_v2")
    end
    
    it "should rename the directory tree with the directory not empty" do
       Dor::ArchiveWorkspaceService.archive_workspace_druid_tree(@druid,"2",@workspace_root)

       File.exists?("#{@druid_tree_path}_v2").should eq true
       File.exists?(@druid_tree_path).should eq false
    end
       
    it "should do nothing with truncated druid" do
      truncated_druid = "druid:tr111tr1111"
      Dor::ArchiveWorkspaceService.archive_workspace_druid_tree(truncated_druid,"2",@workspace_root) 
      truncated_druid_tree_path = "#{@workspace_root}/tr/111/tr/1111/"
      
      File.exists?("#{truncated_druid_tree_path}_v2").should eq false
      File.exists?(truncated_druid_tree_path).should eq true
    end
    
    it "should throw an error if the directory is already archived" do
      expect{ Dor::ArchiveWorkspaceService.archive_workspace_druid_tree(@archived_druid,"2",@workspace_root) }.to raise_error
    end
    
    it "should archived the current directory even if there is an older archived that hasn't been cleaned up" do
      Dor::ArchiveWorkspaceService.archive_workspace_druid_tree(@archived_druid,"3",@workspace_root)
 
      File.exists?("#{@archived_druid_tree_path}_v2").should eq true
      File.exists?("#{@archived_druid_tree_path}_v3").should eq true
      File.exists?("#{@archived_druid_tree_path}").should eq false
      
      #reset the env.

    end
    
    after(:each) do
      #To reset the environment to its original format
      FileUtils.mv(@druid_tree_path+"_v2", @druid_tree_path) if File.exists?(@druid_tree_path+"_v2")
      FileUtils.mv( "#{@archived_druid_tree_path}_v3",@archived_druid_tree_path) if File.exists?(@archived_druid_tree_path+"_v3")

    end
    
  end
end