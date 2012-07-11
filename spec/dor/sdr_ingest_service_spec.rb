require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'fileutils'

describe Dor::SdrIngestService do

  attr_reader :fixture_dir

  before(:all) do
    stub_config
   # @fixture_dir = fixture_dir = File.join(File.dirname(__FILE__),"../fixtures")
   # Dor::Config.push! do
   #   sdr do
   #     local_workspace_root File.join(fixture_dir, "workspace")
   #     local_export_home File.join(fixture_dir, "export")
   #   end
   #end

    export_dir = Dor::Config.sdr.local_export_home
    if (File.exist?(export_dir))
      FileUtils.rm_r(export_dir)
    end
    Dir.mkdir(export_dir)

    @druid = 'druid:aa123bb4567'
    @agreement_id = 'druid:xx098yy7654'

  end
  
  after(:all) do
    unstub_config
    #Dor::Config.pop!
  end
  
  it "can access configuration settings" do
    sdr = Dor::Config.sdr
    sdr.local_workspace_root.should eql File.join(@fixture_dir, "workspace")
    sdr.local_export_home.should eql File.join(@fixture_dir, "export")
  end

  it "can find the fixtures workspace and export folders" do
    File.directory?(Dor::Config.sdr.local_workspace_root).should eql true
    File.directory?(Dor::Config.sdr.local_export_home).should eql true
  end

  it "can retrieve content of a required metadata datastream" do
    ds_name = 'myMetadata'
    metadata_string = '<metadata/>'
    mock_datastream = mock('datastream')
    mock_datastream.should_receive(:new?).and_return(false)
    mock_datastream.should_receive(:content).and_return(metadata_string)
    ds_hash = {ds_name => mock_datastream }
    mock_item = mock("item")
    mock_item.should_receive(:datastreams).exactly(3).times.and_return(ds_hash)
    result = Dor::SdrIngestService.get_datastream_content(mock_item ,ds_name, 'required')
    result.should eql metadata_string
  end

  it "can return nil if optional datastream does not exist in the item" do
    ds_name = 'myMetadata'
    metadata_string = '<metadata/>'
    mock_datastream = mock('datastream')
    mock_datastream.should_receive(:content).never
    ds_hash = {ds_name => mock_datastream }
    mock_item = mock("item")
    mock_item.should_receive(:datastreams).and_return(ds_hash)
    result = Dor::SdrIngestService.get_datastream_content(mock_item ,'dummy', 'optional')
    result.should eql nil
  end

  it "can raise exception if required datastream does not exist in the item" do
    ds_name = 'myMetadata'
    metadata_string = '<metadata/>'
    mock_datastream = mock('datastream')
    mock_datastream.should_receive(:content).never
    ds_hash = {ds_name => mock_datastream }
    mock_item = mock("item")
    mock_item.should_receive(:datastreams).and_return(ds_hash)
    lambda {Dor::SdrIngestService.get_datastream_content(mock_item ,'dummy', 'required')}.should raise_exception
  end

  specify "SdrIngestService.transfer" do
    pending "need to fix creation of content subdir symlink"
    druid = 'druid:ab123cd4567'
    fixtures = Pathname(@fixture_dir)
    workspace = fixtures.join('workspace')
    dor_item = mock('dor item')
    dor_item.stub(:druid).and_return(druid)
    druid_tool = DruidTools::Druid.new(druid,workspace.to_s)
    object_dir = Pathname(druid_tool.path)
    DruidTools::Druid.should_receive(:new).with(druid,Dor::Config.sdr.local_workspace_root).
        and_return(druid_tool)
    signature_catalog = mock("signature catalog")
    signature_catalog.stub(:version_id).and_return(1)
    Dor::SdrIngestService.should_receive(:get_signature_catalog).and_return(signature_catalog)
    metadata_dir = Pathname(druid_tool.path('metadata'))
    Dor::SdrIngestService.should_receive(:extract_datastreams).with(dor_item,metadata_dir)
    version_inventory = mock("version inventory")
    Dor::SdrIngestService.should_receive(:get_version_inventory).with(metadata_dir, druid, 2).
        and_return(version_inventory)
    bag_dir = Pathname(Dor::Config.sdr.local_export_home).join(druid)
    # content_dir.should_receive(:make_symlink)
    bagger = mock(Moab::Bagger)
    Moab::Bagger.should_receive(:new).with(version_inventory, signature_catalog, object_dir, bag_dir).
        and_return(bagger)
    bagger.should_receive(:fill_bag).with(:depositor)
    LyberUtils::FileUtilities.should_receive(:tar_object).with(bag_dir.to_s).and_return(true)
    Dor::SdrIngestService.stub(:read_sdr_workflow_xml).and_return(true)
    Dor::WorkflowService.should_receive(:create_workflow).with(any_args())
    Dor::SdrIngestService.transfer(dor_item)
  end

  specify "SdrIngestService.get_signature_catalog" do
    druid = "druid:gj642zf5650"
    druid_tool = DruidTools::Druid.new(druid,Dor::Config.sdr.local_workspace_root)
    resource = Dor::Config.sdr.rest_client["objects/#{druid}/manifest/signatureCatalog.xml"]
    FakeWeb.register_uri(:get, resource.url, :body => "<signatureCatalog/>")
    Dor::SdrIngestService.get_signature_catalog(druid_tool)

    druid = "druid:zz000zz0000"
    druid_tool = DruidTools::Druid.new(druid,Dor::Config.sdr.local_workspace_root)
    resource = Dor::Config.sdr.rest_client["objects/#{druid}/manifest/signatureCatalog.xml"]
    FakeWeb.register_uri(:get, resource.url, :body => '<signatureCatalog objectId="druid:zz000zz0000" versionId="0" catalogDatetime="" fileCount="0" byteCount="0" blockCount="0"/>')
    catalog = Dor::SdrIngestService.get_signature_catalog(druid_tool)
    catalog.to_xml.should =~ /<signatureCatalog/
    catalog.version_id.should == 0
  end

  specify "SdrIngestService.extract_datastreams" do
    dor_item = mock("workitem")
    metadata_dir = mock("metadata dir")
    metadata_file = mock("metadata path")
    metadata_file.stub(:exist?).and_return(false)
    metadata_dir.should_receive(:join).at_least(5).times.and_return(metadata_file)
    metadata_file.should_receive(:open).at_least(5).times
    #Dor::SdrIngestService.stub(:get_datastream_content).and_return('<metadata/>')
    metadata_string = '<metadata/>'
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(dor_item,'contentMetadata','required').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(dor_item,'descMetadata','required').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(dor_item,'identityMetadata','required').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(dor_item,'provenanceMetadata','required').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(dor_item,'relationshipMetadata','required').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(dor_item,'technicalMetadata','required').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(dor_item,'sourceMetadata','optional').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(dor_item,'rightsMetadata','optional').once.and_return(metadata_string)
    Dor::SdrIngestService.extract_datastreams(dor_item, metadata_dir)
  end

  specify "SdrIngestService.get_version_inventory" do
    metadata_dir = mock(Pathname)
    druid = 'druid:ab123cd4567'
    version_id = 2
    version_inventory = Moab::FileInventory.new()
    version_inventory.groups << Moab::FileGroup.new(:group_id => 'content')
    metadata_group = Moab::FileGroup.new(:group_id => 'metadata')
    Dor::SdrIngestService.should_receive(:get_content_inventory).with(metadata_dir, druid, version_id).
      and_return(version_inventory)
    Dor::SdrIngestService.should_receive(:get_metadata_file_group).with(metadata_dir).
      and_return(metadata_group)
    result = Dor::SdrIngestService.get_version_inventory(metadata_dir, druid, version_id)
    result.should be_instance_of Moab::FileInventory
    result.groups.size.should == 2
  end

  specify "SdrIngestService.get_content_inventory" do
    fixtures = Pathname(@fixture_dir)
    metadata_dir = fixtures.join('workspace/ab/123/cd/4567/ab123cd4567/metadata')
    druid = 'druid:ab123cd4567'
    version_id = 2
    version_inventory = Dor::SdrIngestService.get_content_inventory(metadata_dir, druid, version_id)
    version_inventory.should be_instance_of Moab::FileInventory
    version_inventory.version_id.should == 2
    content_group = version_inventory.groups[0]
    content_group.group_id.should == 'content'
    content_group.files.size.should == 2
    # files in the 2nd resource are copied from the first resource
    content_group.files[0].instances.size.should == 2
  end

  specify "SdrIngestService.get_metadata_file_group" do
    metadata_dir = mock(Pathname)
    file_group = mock(Moab::FileGroup)
    FileGroup.should_receive(:new).with({:group_id=>'metadata'}).and_return(file_group)
    file_group.should_receive(:group_from_directory).with(metadata_dir)
    Dor::SdrIngestService.get_metadata_file_group(metadata_dir)
  end



end