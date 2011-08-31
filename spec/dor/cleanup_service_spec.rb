require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'fileutils'

describe Dor::CleanupService do

  attr_reader :fixture_dir

  before(:all) do
    # see http://stackoverflow.com/questions/5150483/instance-variable-not-available-inside-a-ruby-block
    # Access to instance variables depends on how a block is being called.
    #   If it is called using the yield keyword or the Proc#call method,
    #   then you'll be able to use your instance variables in the block.
    #   If it's called using Object#instance_eval or Module#class_eval
    #   then the context of the block will be changed and you won't be able to access your instance variables.
    # ModCons is using instance_eval, so you cannot use @fixture_dir in the configure call
    @fixture_dir = fixture_dir = File.join(File.dirname(__FILE__),"../fixtures")
    Dor::Config.cleanup.configure do
      local_workspace_root File.join(fixture_dir, "workspace")
      local_export_home File.join(fixture_dir, "export")
   end

    @export_dir = Dor::Config.sdr.local_export_home
    Dir.mkdir(@export_dir) unless File.directory?(@export_dir)
    @druid = 'druid:aa123bb4567'
  end
  
  it "can access configuration settings" do
    cleanup = Dor::Config.cleanup
    cleanup.local_workspace_root.should eql File.join(@fixture_dir, "workspace")
  end

  it "can find the fixtures workspace and export folders" do
    File.directory?(Dor::Config.sdr.local_workspace_root).should eql true
    File.directory?(Dor::Config.sdr.local_export_home).should eql true
  end

  it "can remove a directory" do
    FileUtils.should_receive(:remove_entry).with(@export_dir)
    Dor::CleanupService.remove_entry(@export_dir)
  end

  it "can cleanup an object" do
    mock_item = mock('item')
    mock_item.should_receive(:pid).and_return(@druid)
    Dor::CleanupService.should_receive(:remove_entry).once.with(File.join(@fixture_dir,'workspace/aa/123/bb/4567'))
    Dor::CleanupService.should_receive(:remove_entry).once.with(File.join(@fixture_dir,'export/druid:aa123bb4567'))
    Dor::CleanupService.should_receive(:remove_entry).once.with(File.join(@fixture_dir,'export/druid:aa123bb4567.tar'))
    Dor::CleanupService.cleanup(mock_item)
  end

end