# frozen_string_literal: true

require 'spec_helper'
require 'pathname'
require 'druid-tools'

RSpec.describe Dor::CleanupService do
  attr_reader :fixture_dir

  before(:all) do
    # see http://stackoverflow.com/questions/5150483/instance-variable-not-available-inside-a-ruby-block
    # Access to instance variables depends on how a block is being called.
    #   If it is called using the yield keyword or the Proc#call method,
    #   then you'll be able to use your instance variables in the block.
    #   If it's called using Object#instance_eval or Module#class_eval
    #   then the context of the block will be changed and you won't be able to access your instance variables.
    # ModCons is using instance_eval, so you cannot use @fixture_dir in the configure call
    @fixtures = fixtures = Pathname(File.dirname(__FILE__)).join('../fixtures')

    Dor::Config.push! do
      cleanup.local_workspace_root fixtures.join('workspace').to_s
      cleanup.local_export_home fixtures.join('export').to_s
      cleanup.local_assembly_root fixtures.join('assembly').to_s
    end

    @druid = 'druid:aa123bb4567'
    @workspace_root_pathname = Pathname(Dor::Config.cleanup.local_workspace_root)
    @workitem_pathname       = Pathname(DruidTools::Druid.new(@druid, @workspace_root_pathname.to_s).path)
    @workitem_pathname.rmtree if @workitem_pathname.exist?
    @export_pathname = Pathname(Dor::Config.cleanup.local_export_home)
    @export_pathname.rmtree if @export_pathname.exist?
    @bag_pathname            = @export_pathname.join(@druid.split(':').last)
    @tarfile_pathname        = @export_pathname.join(@bag_pathname + '.tar')
  end

  before do
    @workitem_pathname.join('content').mkpath
    @workitem_pathname.join('temp').mkpath
    @bag_pathname.mkpath
    @tarfile_pathname.open('w') { |file| file.write("test tar\n") }
  end

  after(:all) do
    item_root_branch = @workspace_root_pathname.join('aa')
    item_root_branch.rmtree  if item_root_branch.exist?
    @bag_pathname.rmtree     if @bag_pathname.exist?
    @tarfile_pathname.rmtree if @tarfile_pathname.exist?
    Dor::Config.pop!
  end

  it 'can access configuration settings' do
    cleanup = Dor::Config.cleanup
    expect(cleanup.local_workspace_root).to eql @fixtures.join('workspace').to_s
    expect(cleanup.local_export_home).to eql @fixtures.join('export').to_s
  end

  it 'can find the fixtures workspace and export folders' do
    expect(File).to be_directory(Dor::Config.cleanup.local_workspace_root)
    expect(File).to be_directory(Dor::Config.cleanup.local_export_home)
  end

  specify 'Dor::CleanupService.cleanup' do
    expect(described_class).to receive(:cleanup_export).once.with(@druid)
    mock_item = double('item')
    expect(mock_item).to receive(:druid).and_return(@druid)
    described_class.cleanup(mock_item)
  end

  specify 'Dor::CleanupService.cleanup_export' do
    expect(described_class).to receive(:remove_branch).once.with(@fixtures.join('export/aa123bb4567').to_s)
    expect(described_class).to receive(:remove_branch).once.with(@fixtures.join('export/aa123bb4567.tar').to_s)
    described_class.cleanup_export(@druid)
  end

  specify 'Dor::CleanupService.remove_branch non-existing branch' do
    @bag_pathname.rmtree if @bag_pathname.exist?
    expect(@bag_pathname).not_to receive(:rmtree)
    described_class.remove_branch(@bag_pathname)
  end

  specify 'Dor::CleanupService.remove_branch existing branch' do
    @bag_pathname.mkpath
    expect(@bag_pathname).to exist
    expect(@bag_pathname).to receive(:rmtree)
    described_class.remove_branch(@bag_pathname)
  end

  it 'can do a complete cleanup' do
    expect(@workitem_pathname.join('content')).to exist
    expect(@bag_pathname).to exist
    expect(@tarfile_pathname).to exist
    mock_item = double('item')
    expect(mock_item).to receive(:druid).and_return(@druid)
    described_class.cleanup(mock_item)
    expect(@workitem_pathname.parent.parent.parent.parent).not_to exist
    expect(@bag_pathname).not_to exist
    expect(@tarfile_pathname).not_to exist
  end

  context 'with real files' do
    let(:fixture_dir) { '/tmp/cleanup-spec' }
    let(:workspace_dir) { File.join(fixture_dir, 'workspace') }
    let(:export_dir) { File.join(fixture_dir, 'export') }
    let(:assembly_dir) { File.join(fixture_dir, 'assembly') }
    let(:stacks_dir) { File.join(fixture_dir, 'stacks') }

    let(:druid_1) { 'druid:cd456ef7890' }
    let(:druid_2) { 'druid:cd456gh1234' }

    before do
      Dor::Config.push! do |config|
        config.cleanup.local_workspace_root workspace_dir
        config.cleanup.local_export_home export_dir
        config.cleanup.local_assembly_root assembly_dir
        config.stacks.local_stacks_root stacks_dir
      end

      FileUtils.mkdir fixture_dir
      FileUtils.mkdir workspace_dir
      FileUtils.mkdir export_dir
      FileUtils.mkdir assembly_dir
      FileUtils.mkdir stacks_dir
    end

    after do
      FileUtils.rm_rf fixture_dir
      Dor::Config.pop!
    end

    def create_tempfile(path)
      File.open(File.join(path, 'tempfile'), 'w') do |tf1|
        tf1.write 'junk'
      end
    end

    context '.cleanup' do
      let(:item1) { double('item1') }
      let(:item2) { double('item1') }

      before do
        allow(item1).to receive(:druid) { druid_1 }
        allow(item2).to receive(:druid) { druid_2 }
      end

      it 'correctly prunes directories' do
        dr1_wspace = DruidTools::Druid.new(druid_1, workspace_dir)
        dr2_wspace = DruidTools::Druid.new(druid_2, workspace_dir)
        dr1_assembly = DruidTools::Druid.new(druid_1, assembly_dir)
        dr2_assembly = DruidTools::Druid.new(druid_2, assembly_dir)

        dr1_wspace.mkdir
        dr2_wspace.mkdir
        dr1_assembly.mkdir
        dr2_assembly.mkdir

        # Add some 'content'
        create_tempfile dr1_wspace.path
        create_tempfile dr2_assembly.path

        # Setup the export content, remove 'druid:' prefix for bag and export/workspace dir
        dr1 = druid_1.split(':').last
        export_prefix_1 = File.join(export_dir, dr1)

        # Create {export_dir}/druid1
        #        {export_dir}/druid1/tempfile
        #        {export_dir}/druid1.tar
        FileUtils.mkdir export_prefix_1
        create_tempfile export_prefix_1
        File.open(export_prefix_1 + '.tar', 'w') { |f| f.write 'fake tar junk' }

        expect(File).to exist(dr1_wspace.path)
        expect(File).to exist(dr1_assembly.path)

        # druid_1 cleaned up, including files
        Dor::CleanupService.cleanup item1
        expect(File).not_to exist(dr1_wspace.path)
        expect(File).not_to exist(dr1_assembly.path)
        expect(File).not_to exist(export_prefix_1)
        expect(File).not_to exist(export_prefix_1 + '.tar')

        # But not druid_2
        expect(File).to exist(dr2_wspace.path)
        expect(File).to exist(dr2_assembly.path)

        Dor::CleanupService.cleanup item2
        expect(File).not_to exist(dr2_wspace.path)
        expect(File).not_to exist(dr2_assembly.path)

        # Empty common parent directories pruned
        expect(File).not_to exist(File.join(workspace_dir, 'cd'))
      end

      it 'cleans up without assembly content' do
        dr1_wspace = DruidTools::Druid.new(druid_1, workspace_dir)
        dr1_wspace.mkdir

        Dor::CleanupService.cleanup item1
        expect(File).not_to exist(dr1_wspace.path)
      end
    end

    context '.cleanup_stacks' do
      it 'prunes the item from the local stacks root' do
        stacks_dr = DruidTools::StacksDruid.new(druid_1, Dor::Config.stacks.local_stacks_root)
        stacks_dr.mkdir

        create_tempfile stacks_dr.path
        expect(File).to exist(stacks_dr.path)

        Dor::CleanupService.cleanup_stacks druid_1
        expect(File).not_to exist(stacks_dr.path)
      end
    end
  end
end
