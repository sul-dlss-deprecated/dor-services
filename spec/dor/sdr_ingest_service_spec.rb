require 'spec_helper'
require 'fileutils'

describe Dor::SdrIngestService do

  before(:each) do
    @fixtures = fixtures = Pathname(File.dirname(__FILE__)).join('../fixtures')
    Dor::Config.push! do
      sdr.local_workspace_root fixtures.join('workspace').to_s
      sdr.local_export_home    fixtures.join('export').to_s
    end

    @export_dir = Pathname(Dor::Config.sdr.local_export_home)
    @export_dir.rmtree if @export_dir.exist? && @export_dir.basename.to_s == 'export'
    @export_dir.mkdir
    @druid        = 'druid:aa123bb4567'
    @agreement_id = 'druid:xx098yy7654'
  end

  after(:each) do
    Dor::Config.pop!
    @export_dir.rmtree if @export_dir.exist? && @export_dir.basename.to_s == 'export'
  end

  it 'can access configuration settings' do
    sdr = Dor::Config.sdr
    expect(sdr.local_workspace_root).to eq @fixtures.join('workspace').to_s
    expect(sdr.local_export_home).to eq @fixtures.join('export').to_s
  end

  it 'can find the fixtures workspace and export folders' do
    expect(File.directory?(Dor::Config.sdr.local_workspace_root)).to be_truthy
    expect(File.directory?(Dor::Config.sdr.local_export_home)).to be_truthy
  end

  describe 'get_datastream_content' do
    before :each do
      @ds_name = 'myMetadata'
      @mock_item = double('item')
      @mock_datastream = double('datastream')
    end
    it 'retrieves content of a required datastream' do
      metadata_string = '<metadata/>'
      expect(@mock_datastream).to receive(:new?).and_return(false)
      expect(@mock_datastream).to receive(:content).and_return(metadata_string)
      expect(@mock_item).to receive(:datastreams).exactly(3).times.and_return({ @ds_name => @mock_datastream })
      expect(Dor::SdrIngestService.get_datastream_content(@mock_item, @ds_name, 'required')).to eq metadata_string
    end
    context 'when datastream is empty or missing' do
      before :each do
        expect(@mock_datastream).not_to receive(:content)
        expect(@mock_item).to receive(:datastreams).and_return({ @ds_name => @mock_datastream })
      end
      it 'returns nil if datastream was optional' do
        expect(Dor::SdrIngestService.get_datastream_content(@mock_item, 'dummy', 'optional')).to be_nil
      end
      it 'raises exception if datastream was required' do
        expect{Dor::SdrIngestService.get_datastream_content(@mock_item, 'dummy', 'required')}.to raise_exception(RuntimeError)
      end
    end
  end

  describe 'transfer' do
    before :each do
      druid = 'druid:dd116zh0343'
      @dor_item = double('dor_item')
      expect(@dor_item).to receive(:initialize_workflow).with('sdrIngestWF', false)
      allow(@dor_item).to receive(:pid).and_return(druid)
      signature_catalog = Moab::SignatureCatalog.read_xml_file(@fixtures.join('sdr_repo/dd116zh0343/v0001/manifests'))
      @metadata_dir = @fixtures.join('workspace/dd/116/zh/0343/dd116zh0343/metadata')
      expect(Dor::SdrIngestService).to receive(:get_signature_catalog).with(druid).and_return(signature_catalog)
      expect(Dor::SdrIngestService).to receive(:extract_datastreams).with(@dor_item, an_instance_of(DruidTools::Druid)).and_return(@metadata_dir)
      @files = []
    end
    specify 'with content changes' do
      Dor::SdrIngestService.transfer(@dor_item)
      @fixtures.join('export/dd116zh0343').find { |f| @files << f.relative_path_from(@fixtures).to_s }
      expect(@files.sort).to eq([
          'export/dd116zh0343',
          'export/dd116zh0343/bag-info.txt',
          'export/dd116zh0343/bagit.txt',
          'export/dd116zh0343/data',
          'export/dd116zh0343/data/content',
          'export/dd116zh0343/data/content/folder1PuSu',
          'export/dd116zh0343/data/content/folder1PuSu/story3m.txt',
          'export/dd116zh0343/data/content/folder1PuSu/story5a.txt',
          'export/dd116zh0343/data/content/folder3PaSd',
          'export/dd116zh0343/data/content/folder3PaSd/storyDm.txt',
          'export/dd116zh0343/data/content/folder3PaSd/storyFa.txt',
          'export/dd116zh0343/data/metadata',
          'export/dd116zh0343/data/metadata/contentMetadata.xml',
          'export/dd116zh0343/data/metadata/tech-generated.xml',
          'export/dd116zh0343/data/metadata/technicalMetadata.xml',
          'export/dd116zh0343/data/metadata/versionMetadata.xml',
          'export/dd116zh0343/manifest-md5.txt',
          'export/dd116zh0343/manifest-sha1.txt',
          'export/dd116zh0343/manifest-sha256.txt',
          'export/dd116zh0343/tagmanifest-md5.txt',
          'export/dd116zh0343/tagmanifest-sha1.txt',
          'export/dd116zh0343/tagmanifest-sha256.txt',
          'export/dd116zh0343/versionAdditions.xml',
          'export/dd116zh0343/versionInventory.xml'])
    end
    specify 'with no change in content' do
      v1_content_metadata = @fixtures.join('sdr_repo/dd116zh0343/v0001/data/metadata/contentMetadata.xml')
      expect(Dor::SdrIngestService).to receive(:get_content_metadata).with(@metadata_dir).and_return(v1_content_metadata.read)
      Dor::SdrIngestService.transfer(@dor_item)
      @fixtures.join('export/dd116zh0343').find { |f| @files << f.relative_path_from(@fixtures).to_s }
      expect(@files.sort).to eq([
          'export/dd116zh0343',
          'export/dd116zh0343/bag-info.txt',
          'export/dd116zh0343/bagit.txt',
          'export/dd116zh0343/data',
          'export/dd116zh0343/data/metadata',
          'export/dd116zh0343/data/metadata/contentMetadata.xml',
          'export/dd116zh0343/data/metadata/tech-generated.xml',
          'export/dd116zh0343/data/metadata/technicalMetadata.xml',
          'export/dd116zh0343/data/metadata/versionMetadata.xml',
          'export/dd116zh0343/manifest-md5.txt',
          'export/dd116zh0343/manifest-sha1.txt',
          'export/dd116zh0343/manifest-sha256.txt',
          'export/dd116zh0343/tagmanifest-md5.txt',
          'export/dd116zh0343/tagmanifest-sha1.txt',
          'export/dd116zh0343/tagmanifest-sha256.txt',
          'export/dd116zh0343/versionAdditions.xml',
          'export/dd116zh0343/versionInventory.xml'])
    end
  end

  specify 'get_signature_catalog' do
    druid = 'druid:zz000zz0000'
    resource = Dor::Config.sdr.rest_client["objects/#{druid}/manifest/signatureCatalog.xml"]
    stub_request(:get, resource.url).to_return(:body => '<signatureCatalog objectId="druid:zz000zz0000" versionId="0" catalogDatetime="" fileCount="0" byteCount="0" blockCount="0"/>')
    catalog = Dor::SdrIngestService.get_signature_catalog(druid)
    # p catalog
    # p catalog.to_xml
    expect(catalog.to_xml).to match(/<signatureCatalog/)
    expect(catalog.version_id).to eq 0
  end

  specify 'extract_datastreams' do
    dor_item = double('workitem')
    metadata_dir = double('metadata dir')
    workspace = double('workspace')
    allow(workspace).to receive(:path).with('metadata', true).and_return('metadata_dir')
    expect(Pathname).to receive(:new).with('metadata_dir').and_return(metadata_dir)
    metadata_file = double('metadata path')
    allow(metadata_file).to receive(:exist?).and_return(false)
    expect(metadata_dir).to receive(:join).at_least(5).times.and_return(metadata_file)
    expect(metadata_file).to receive(:open).at_least(5).times
    # Dor::SdrIngestService.stub(:get_datastream_content).and_return('<metadata/>')
    metadata_string = '<metadata/>'
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item, 'contentMetadata', 'required').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item, 'descMetadata', 'required').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item, 'identityMetadata', 'required').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item, 'provenanceMetadata', 'required').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item, 'relationshipMetadata', 'required').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item, 'technicalMetadata', 'required').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item, 'sourceMetadata', 'optional').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item, 'rightsMetadata', 'optional').once.and_return(metadata_string)
    Dor::SdrIngestService.extract_datastreams(dor_item, workspace)
  end

  specify 'get_version_inventory' do
    metadata_dir = double(Pathname)
    druid = 'druid:ab123cd4567'
    version_id = 2
    version_inventory = Moab::FileInventory.new
    version_inventory.groups << Moab::FileGroup.new(:group_id => 'content')
    metadata_group = Moab::FileGroup.new(:group_id => 'metadata')
    expect(Dor::SdrIngestService).to receive(:get_content_inventory).with(metadata_dir, druid, version_id).and_return(version_inventory)
    expect(Dor::SdrIngestService).to receive(:get_metadata_file_group).with(metadata_dir).and_return(metadata_group)
    result = Dor::SdrIngestService.get_version_inventory(metadata_dir, druid, version_id)
    expect(result).to be_instance_of Moab::FileInventory
    expect(result.groups.size).to eq 2
  end

  specify 'get_content_inventory' do
    metadata_dir = @fixtures.join('workspace/ab/123/cd/4567/ab123cd4567/metadata')
    druid = 'druid:ab123cd4567'
    version_id = 2

    version_inventory = Dor::SdrIngestService.get_content_inventory(metadata_dir, druid, version_id)
    expect(version_inventory).to be_instance_of Moab::FileInventory
    expect(version_inventory.version_id).to eq 2
    content_group = version_inventory.groups[0]
    expect(content_group.group_id).to eq 'content'
    expect(content_group.files.size).to eq 2
    # files in the 2nd resource are copied from the first resource
    expect(content_group.files[0].instances.size).to eq 2

    # if no content metadata
    metadata_dir = @fixtures.join('workspace/ab/123/cd/4567/ab123cd4567')
    version_inventory = Dor::SdrIngestService.get_content_inventory(metadata_dir, druid, version_id)
    expect(version_inventory.groups.size).to eq 0
  end

  specify 'get_content_metadata' do
    metadata_dir = @fixtures.join('workspace/ab/123/cd/4567/ab123cd4567/metadata')
    content_metadata = Dor::SdrIngestService.get_content_metadata(metadata_dir)
    expect(content_metadata).to match(/<contentMetadata /)

    # if no content metadata
    metadata_dir = @fixtures.join('workspace/ab/123/cd/4567/ab123cd4567')
    content_metadata = Dor::SdrIngestService.get_content_metadata(metadata_dir)
    expect(content_metadata).to be_nil
  end

  specify 'get_metadata_file_group' do
    metadata_dir = double(Pathname)
    file_group = double(Moab::FileGroup)
    expect(FileGroup).to receive(:new).with({:group_id => 'metadata'}).and_return(file_group)
    expect(file_group).to receive(:group_from_directory).with(metadata_dir)
    Dor::SdrIngestService.get_metadata_file_group(metadata_dir)
  end

  specify 'verify_version_id' do
    expect(Dor::SdrIngestService.verify_version_id('/mypath/myfile', 2, 2)).to be_truthy
    expect{Dor::SdrIngestService.verify_version_id('/mypath/myfile', 1, 2)}.to raise_exception('Version mismatch in /mypath/myfile, expected 1, found 2')
  end

  specify 'vmfile_version_id' do
    metadata_dir = @fixtures.join('workspace/dd/116/zh/0343/dd116zh0343/metadata')
    vmfile = metadata_dir.join('versionMetadata.xml')
    expect(Dor::SdrIngestService.vmfile_version_id(vmfile)).to eq 2
  end

  specify 'verify_pathname' do
    metadata_dir = @fixtures.join('workspace/dd/116/zh/0343/dd116zh0343/metadata')
    expect(Dor::SdrIngestService.verify_pathname(metadata_dir)).to be_truthy
    vmfile = metadata_dir.join('versionMetadata.xml')
    expect(Dor::SdrIngestService.verify_pathname(vmfile)).to be_truthy
    badfile = metadata_dir.join('badfile.xml')
    expect{Dor::SdrIngestService.verify_pathname(badfile)}.to raise_exception(/badfile.xml not found/)
  end
end
