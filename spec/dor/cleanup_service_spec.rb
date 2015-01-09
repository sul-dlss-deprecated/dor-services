require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'pathname'
require 'druid-tools'

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
    @fixtures=fixtures=Pathname(File.dirname(__FILE__)).join("../fixtures")

    Dor::Config.push! do
      cleanup.local_workspace_root fixtures.join("workspace").to_s
      cleanup.local_export_home fixtures.join("export").to_s
   end


    @druid = 'druid:aa123bb4567'
    @workspace_root_pathname = Pathname(Dor::Config.cleanup.local_workspace_root)
    @workitem_pathname = Pathname(DruidTools::Druid.new(@druid,@workspace_root_pathname.to_s).path)
    @workitem_pathname.rmtree if @workitem_pathname.exist?
    @export_pathname = Pathname(Dor::Config.cleanup.local_export_home)
    @export_pathname.rmtree if @export_pathname.exist?
    @bag_pathname = @export_pathname.join(@druid.split(':').last)
    @tarfile_pathname = @export_pathname.join(@bag_pathname+".tar")
  end

  before(:each) do
    @workitem_pathname.join('content').mkpath
    @workitem_pathname.join('temp').mkpath
    @bag_pathname.mkpath
    @tarfile_pathname.open('w') { |file| file.write("test tar\n") }
  end

  after(:all) do
    item_root_branch = @workspace_root_pathname.join('aa')
    item_root_branch.rmtree if item_root_branch.exist?
    @bag_pathname.rmtree if @bag_pathname.exist?
    @tarfile_pathname.rmtree if @tarfile_pathname.exist?
    Dor::Config.pop!
  end

  it "can access configuration settings" do
    cleanup = Dor::Config.cleanup
    expect(cleanup.local_workspace_root).to eql @fixtures.join("workspace").to_s
    expect(cleanup.local_export_home).to eql @fixtures.join("export").to_s
  end

  it "can find the fixtures workspace and export folders" do
    expect(File.directory?(Dor::Config.cleanup.local_workspace_root)).to eql true
    expect(File.directory?(Dor::Config.cleanup.local_export_home)).to eql true
  end

  specify "Dor::CleanupService.cleanup" do
    expect(Dor::CleanupService).to receive(:cleanup_export).once.with(@druid)
    mock_item = double('item')
    expect(mock_item).to receive(:druid).and_return(@druid)
    Dor::CleanupService.cleanup(mock_item)
  end

  specify "Dor::CleanupService.cleanup_export" do
    expect(Dor::CleanupService).to receive(:remove_branch).once.with(@fixtures.join('export/aa123bb4567').to_s)
    expect(Dor::CleanupService).to receive(:remove_branch).once.with(@fixtures.join('export/aa123bb4567.tar').to_s)
    Dor::CleanupService.cleanup_export(@druid)
  end

  specify "Dor::CleanupService.remove_branch non-existing branch" do
    @bag_pathname.rmtree if @bag_pathname.exist?
    expect(@bag_pathname).not_to receive(:rmtree)
    Dor::CleanupService.remove_branch(@bag_pathname)
  end

  specify "Dor::CleanupService.remove_branch existing branch" do
    @bag_pathname.mkpath
    expect(@bag_pathname.exist?).to eq(true)
    expect(@bag_pathname).to receive(:rmtree)
    Dor::CleanupService.remove_branch(@bag_pathname)
  end

  it "can do a complete cleanup" do
    expect(@workitem_pathname.join('content').exist?).to eq(true)
    expect(@bag_pathname.exist?).to eq(true)
    expect(@tarfile_pathname.exist?).to eq(true)
    mock_item = double('item')
    expect(mock_item).to receive(:druid).and_return(@druid)
    Dor::CleanupService.cleanup(mock_item)
    expect(@workitem_pathname.parent.parent.parent.parent.exist?).to eq(false)
    expect(@bag_pathname.exist?).to eq(false)
    expect(@tarfile_pathname.exist?).to eq(false)

  end

end