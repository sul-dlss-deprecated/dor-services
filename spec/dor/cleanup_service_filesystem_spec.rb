require 'spec_helper'

describe 'Dor::CleanupService specs that check the file system' do

  let(:fixture_dir) { '/tmp/cleanup-spec' }
  let(:workspace_dir) { File.join(fixture_dir, 'workspace')}
  let(:export_dir) { File.join(fixture_dir, 'export')}
  let(:assembly_dir) { File.join(fixture_dir, 'assembly')}
  let(:stacks_dir) { File.join(fixture_dir, 'stacks')}

  let(:druid_1) {'druid:cd456ef7890'}
  let(:druid_2) {'druid:cd456gh1234'}

  before(:each) do
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

  after(:each) do
    FileUtils.rm_rf fixture_dir
    Dor::Config.pop!
  end

  def create_tempfile(path)
    File.open(File.join(path, 'tempfile'), 'w') do |tf1|
      tf1.write 'junk'
    end
  end

  context "CleanupService.cleanup" do
    let(:item1) { double('item1') }
    let(:item2) { double('item1') }

    before(:each) do
      allow(item1).to receive(:druid) { druid_1 }
      allow(item2).to receive(:druid) { druid_2 }
    end

    it "correctly prunes directories" do
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
      File.open(export_prefix_1 + '.tar', 'w') {|f| f.write 'fake tar junk'}

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

    it "cleans up without assembly content" do
      dr1_wspace = DruidTools::Druid.new(druid_1, workspace_dir)
      dr1_wspace.mkdir

      Dor::CleanupService.cleanup item1
      expect(File).not_to exist(dr1_wspace.path)
    end
  end

  context 'CleanupService.cleanup_stacks' do

    it 'prunes the item from the local stacks root' do
      stacks_dr = DruidTools::StacksDruid.new(druid_1, Dor::Config.stacks.local_stacks_root)
      stacks_dr.mkdir

      create_tempfile stacks_dr.path
      expect(File).to exist(stacks_dr.path)

      Dor::CleanupService.cleanup_stacks druid_1
      expect(File).to_not exist(stacks_dr.path)

    end

  end



end
