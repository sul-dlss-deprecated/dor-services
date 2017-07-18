require 'spec_helper'
require 'fileutils'

describe Dor::SdrIngestService do

  before(:each) do
    @fixtures=fixtures=Pathname(File.dirname(__FILE__)).join("../fixtures")
    Dor::Config.push! do
      sdr.local_workspace_root fixtures.join("workspace").to_s
      sdr.local_export_home fixtures.join("export").to_s
    end

    @export_dir = Pathname(Dor::Config.sdr.local_export_home)
    if @export_dir.exist? and @export_dir.basename.to_s == 'export'
      @export_dir.rmtree
    end
    @export_dir.mkdir

    @druid = 'druid:aa123bb4567'
    @agreement_id = 'druid:xx098yy7654'

  end

  after(:each) do
    Dor::Config.pop!
    if @export_dir.exist? and @export_dir.basename.to_s == 'export'
      @export_dir.rmtree
    end
  end

  it "can access configuration settings" do
    sdr = Dor::Config.sdr
    expect(sdr.local_workspace_root).to eql @fixtures.join("workspace").to_s
    expect(sdr.local_export_home).to eql @fixtures.join("export").to_s
  end

  it "can find the fixtures workspace and export folders" do
    expect(File.directory?(Dor::Config.sdr.local_workspace_root)).to eql true
    expect(File.directory?(Dor::Config.sdr.local_export_home)).to eql true
  end

  it "can retrieve content of a required metadata datastream" do
    ds_name = 'myMetadata'
    metadata_string = '<metadata/>'
    mock_datastream = double('datastream')
    expect(mock_datastream).to receive(:new?).and_return(false)
    expect(mock_datastream).to receive(:content).and_return(metadata_string)
    ds_hash = {ds_name => mock_datastream }
    mock_item = double("item")
    expect(mock_item).to receive(:datastreams).exactly(3).times.and_return(ds_hash)
    result = Dor::SdrIngestService.get_datastream_content(mock_item ,ds_name, 'required')
    expect(result).to eql metadata_string
  end

  it "can return nil if optional datastream does not exist in the item" do
    ds_name = 'myMetadata'
    metadata_string = '<metadata/>'
    mock_datastream = double('datastream')
    expect(mock_datastream).to receive(:content).never
    ds_hash = {ds_name => mock_datastream }
    mock_item = double("item")
    expect(mock_item).to receive(:datastreams).and_return(ds_hash)
    result = Dor::SdrIngestService.get_datastream_content(mock_item ,'dummy', 'optional')
    expect(result).to eql nil
  end

  it "can raise exception if required datastream does not exist in the item" do
    ds_name = 'myMetadata'
    metadata_string = '<double/>'
    mock_datastream = double('datastream')
    expect(mock_datastream).to receive(:content).never
    ds_hash = {ds_name => mock_datastream }
    mock_item = double("item")
    expect(mock_item).to receive(:datastreams).and_return(ds_hash)
    expect {Dor::SdrIngestService.get_datastream_content(mock_item ,'dummy', 'required')}.to raise_exception
  end

  specify "SdrIngestService.transfer with content changes" do
    druid = 'druid:dd116zh0343'
    dor_item = double("dor_item")
    expect(dor_item).to receive(:initialize_workflow).with('sdrIngestWF', false)
    allow(dor_item).to receive(:pid).and_return(druid)
    signature_catalog=Moab::SignatureCatalog.read_xml_file(@fixtures.join('sdr_repo/dd116zh0343/v0001/manifests'))
    expect(Dor::SdrIngestService).to receive(:get_signature_catalog).with(druid).
        and_return(signature_catalog)
    metadata_dir = @fixtures.join('workspace/dd/116/zh/0343/dd116zh0343/metadata')
    expect(Dor::SdrIngestService).to receive(:extract_datastreams).with(dor_item, an_instance_of(DruidTools::Druid)).
        and_return(metadata_dir)
    Dor::SdrIngestService.transfer(dor_item)
    files = Array.new
    @fixtures.join('export/dd116zh0343').find { |f| files << f.relative_path_from(@fixtures).to_s }
    expect(files.sort).to eq([
        "export/dd116zh0343",
        "export/dd116zh0343/bag-info.txt",
        "export/dd116zh0343/bagit.txt",
        "export/dd116zh0343/data",
        "export/dd116zh0343/data/content",
        "export/dd116zh0343/data/content/folder1PuSu",
        "export/dd116zh0343/data/content/folder1PuSu/story3m.txt",
        "export/dd116zh0343/data/content/folder1PuSu/story5a.txt",
        "export/dd116zh0343/data/content/folder3PaSd",
        "export/dd116zh0343/data/content/folder3PaSd/storyDm.txt",
        "export/dd116zh0343/data/content/folder3PaSd/storyFa.txt",
        "export/dd116zh0343/data/metadata",
        "export/dd116zh0343/data/metadata/contentMetadata.xml",
        "export/dd116zh0343/data/metadata/tech-generated.xml",
        "export/dd116zh0343/data/metadata/technicalMetadata.xml",
        "export/dd116zh0343/data/metadata/versionMetadata.xml",
        "export/dd116zh0343/manifest-md5.txt",
        "export/dd116zh0343/manifest-sha1.txt",
        "export/dd116zh0343/manifest-sha256.txt",
        "export/dd116zh0343/tagmanifest-md5.txt",
        "export/dd116zh0343/tagmanifest-sha1.txt",
        "export/dd116zh0343/tagmanifest-sha256.txt",
        "export/dd116zh0343/versionAdditions.xml",
        "export/dd116zh0343/versionInventory.xml"])
  end

  specify "SdrIngestService.transfer with no change in content" do
    druid = 'druid:dd116zh0343'
    dor_item = double("dor_item")
    expect(dor_item).to receive(:initialize_workflow).with('sdrIngestWF', false)
    allow(dor_item).to receive(:pid).and_return(druid)
    signature_catalog=Moab::SignatureCatalog.read_xml_file(@fixtures.join('sdr_repo/dd116zh0343/v0001/manifests'))
    expect(Dor::SdrIngestService).to receive(:get_signature_catalog).with(druid).
        and_return(signature_catalog)
    metadata_dir = @fixtures.join('workspace/dd/116/zh/0343/dd116zh0343/metadata')
    v1_content_metadata = @fixtures.join('sdr_repo/dd116zh0343/v0001/data/metadata/contentMetadata.xml')
    expect(Dor::SdrIngestService).to receive(:get_content_metadata).with(metadata_dir).
            and_return(v1_content_metadata.read)
    expect(Dor::SdrIngestService).to receive(:extract_datastreams).with(dor_item, an_instance_of(DruidTools::Druid)).
        and_return(metadata_dir)
    Dor::SdrIngestService.transfer(dor_item)
    files = Array.new
    @fixtures.join('export/dd116zh0343').find { |f| files << f.relative_path_from(@fixtures).to_s }
    expect(files.sort).to eq([
        "export/dd116zh0343",
        "export/dd116zh0343/bag-info.txt",
        "export/dd116zh0343/bagit.txt",
        "export/dd116zh0343/data",
        "export/dd116zh0343/data/metadata",
        "export/dd116zh0343/data/metadata/contentMetadata.xml",
        "export/dd116zh0343/data/metadata/tech-generated.xml",
        "export/dd116zh0343/data/metadata/technicalMetadata.xml",
        "export/dd116zh0343/data/metadata/versionMetadata.xml",
        "export/dd116zh0343/manifest-md5.txt",
        "export/dd116zh0343/manifest-sha1.txt",
        "export/dd116zh0343/manifest-sha256.txt",
        "export/dd116zh0343/tagmanifest-md5.txt",
        "export/dd116zh0343/tagmanifest-sha1.txt",
        "export/dd116zh0343/tagmanifest-sha256.txt",
        "export/dd116zh0343/versionAdditions.xml",
        "export/dd116zh0343/versionInventory.xml"])
  end

  specify "SdrIngestService.get_signature_catalog" do
    druid = "druid:zz000zz0000"
    resource = Dor::Config.sdr.rest_client["objects/#{druid}/manifest/signatureCatalog.xml"]
    FakeWeb.register_uri(:get, resource.url, :body => '<signatureCatalog objectId="druid:zz000zz0000" versionId="0" catalogDatetime="" fileCount="0" byteCount="0" blockCount="0"/>')
    catalog = Dor::SdrIngestService.get_signature_catalog(druid)
    p catalog
    p catalog.to_xml
    expect(catalog.to_xml).to match(/<signatureCatalog/)
    expect(catalog.version_id).to eq(0)
  end

  specify "SdrIngestService.extract_datastreams" do
    dor_item = double("workitem")
    metadata_dir = double("metadata dir")
    workspace = double("workspace")
    allow(workspace).to receive(:path).with("metadata",true).and_return("metadata_dir")
    expect(Pathname).to receive(:new).with("metadata_dir").and_return(metadata_dir)
    metadata_file = double("metadata path")
    allow(metadata_file).to receive(:exist?).and_return(false)
    expect(metadata_dir).to receive(:join).at_least(5).times.and_return(metadata_file)
    expect(metadata_file).to receive(:open).at_least(5).times
    #Dor::SdrIngestService.stub(:get_datastream_content).and_return('<metadata/>')
    metadata_string = '<metadata/>'
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item,'contentMetadata','required').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item,'descMetadata','required').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item,'identityMetadata','required').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item,'provenanceMetadata','required').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item,'relationshipMetadata','required').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item,'technicalMetadata','required').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item,'sourceMetadata','optional').once.and_return(metadata_string)
    expect(Dor::SdrIngestService).to receive(:get_datastream_content).with(dor_item,'rightsMetadata','optional').once.and_return(metadata_string)
    Dor::SdrIngestService.extract_datastreams(dor_item, workspace)
  end

  specify "SdrIngestService.get_version_inventory" do
    metadata_dir = double(Pathname)
    druid = 'druid:ab123cd4567'
    version_id = 2
    version_inventory = Moab::FileInventory.new()
    version_inventory.groups << Moab::FileGroup.new(:group_id => 'content')
    metadata_group = Moab::FileGroup.new(:group_id => 'metadata')
    expect(Dor::SdrIngestService).to receive(:get_content_inventory).with(metadata_dir, druid, version_id).
      and_return(version_inventory)
    expect(Dor::SdrIngestService).to receive(:get_metadata_file_group).with(metadata_dir).
      and_return(metadata_group)
    result = Dor::SdrIngestService.get_version_inventory(metadata_dir, druid, version_id)
    expect(result).to be_instance_of Moab::FileInventory
    expect(result.groups.size).to eq(2)
  end

  specify "SdrIngestService.get_content_inventory" do
    metadata_dir = @fixtures.join('workspace/ab/123/cd/4567/ab123cd4567/metadata')
    druid = 'druid:ab123cd4567'
    version_id = 2

    version_inventory = Dor::SdrIngestService.get_content_inventory(metadata_dir, druid, version_id)
    expect(version_inventory).to be_instance_of Moab::FileInventory
    expect(version_inventory.version_id).to eq(2)
    content_group = version_inventory.groups[0]
    expect(content_group.group_id).to eq('content')
    expect(content_group.files.size).to eq(2)
    # files in the 2nd resource are copied from the first resource
    expect(content_group.files[0].instances.size).to eq(2)

    # if no content metadata
    metadata_dir = @fixtures.join('workspace/ab/123/cd/4567/ab123cd4567')
    version_inventory = Dor::SdrIngestService.get_content_inventory(metadata_dir, druid, version_id)
    expect(version_inventory.groups.size).to eq(0)
  end

  specify "SdrIngestService.get_content_metadata" do
    metadata_dir = @fixtures.join('workspace/ab/123/cd/4567/ab123cd4567/metadata')
    content_metadata = Dor::SdrIngestService.get_content_metadata(metadata_dir)
    expect(content_metadata).to match(/<contentMetadata /)

    # if no content metadata
    metadata_dir = @fixtures.join('workspace/ab/123/cd/4567/ab123cd4567')
    content_metadata = Dor::SdrIngestService.get_content_metadata(metadata_dir)
    expect(content_metadata).to be_nil
  end

  specify "SdrIngestService.get_metadata_file_group" do
    metadata_dir = double(Pathname)
    file_group = double(Moab::FileGroup)
    expect(FileGroup).to receive(:new).with({:group_id=>'metadata'}).and_return(file_group)
    expect(file_group).to receive(:group_from_directory).with(metadata_dir)
    Dor::SdrIngestService.get_metadata_file_group(metadata_dir)
  end

  specify "SdrIngestService.verify_version_id" do
    expect(Dor::SdrIngestService.verify_version_id("/mypath/myfile", expected=2, found=2)).to eq(true)
    expect{Dor::SdrIngestService.verify_version_id("/mypath/myfile", expected=1, found=2)}.
      to raise_exception("Version mismatch in /mypath/myfile, expected 1, found 2")
  end

  specify "SdrIngestService.vmfile_version_id" do
    metadata_dir = @fixtures.join('workspace/dd/116/zh/0343/dd116zh0343/metadata')
    vmfile = metadata_dir.join("versionMetadata.xml")
    expect(Dor::SdrIngestService.vmfile_version_id(vmfile)).to eq(2)
  end

  specify "SdrIngestService.verify_pathname" do
    metadata_dir = @fixtures.join('workspace/dd/116/zh/0343/dd116zh0343/metadata')
    expect(Dor::SdrIngestService.verify_pathname(metadata_dir)).to eq(true)
    vmfile = metadata_dir.join("versionMetadata.xml")
    expect(Dor::SdrIngestService.verify_pathname(vmfile)).to eq(true)
    badfile = metadata_dir.join("badfile.xml")
    expect{Dor::SdrIngestService.verify_pathname(badfile)}.to  raise_exception(/badfile.xml not found/)

  end
end
