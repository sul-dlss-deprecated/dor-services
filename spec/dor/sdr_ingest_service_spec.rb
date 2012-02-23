require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'fileutils'

describe Dor::SdrIngestService do

  attr_reader :fixture_dir

  before(:all) do
    @fixture_dir = fixture_dir = File.join(File.dirname(__FILE__),"../fixtures")
    Dor::Config.push! do
      sdr do
        local_workspace_root File.join(fixture_dir, "workspace")
        local_export_home File.join(fixture_dir, "export")
      end
   end

    export_dir = Dor::Config.sdr.local_export_home
    if (File.exist?(export_dir))
      FileUtils.rm_r(export_dir)
    end
    Dir.mkdir(export_dir)

    @druid = 'druid:aa123bb4567'
    @agreement_id = 'druid:xx098yy7654'

  end
  
  after(:all) do
    Dor::Config.pop!
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

  it "can create a metadata-info hash" do
    mi = Dor::SdrIngestService.metadata_info(@druid, @agreement_id)
    mi["Stanford-Provenance-Metadata"].should eql "data/metadata/provenanceMetadata.xml"
    mi["Stanford-Identity-Metadata"].should eql"data/metadata/identityMetadata.xml"
    mi["Stanford-Content-Metadata"].should eql"data/metadata/contentMetadata.xml"
    mi["External-Identifier"].should eql @druid
    mi["Stanford-Agreement-ID"].should eql @agreement_id
  end

  it "can retrieve content of a required metadata datastream" do
    ds_name = 'myMetadata'
    metadata_string = '<metadata/>'
    mock_datastream = mock('datastream')
    mock_datastream.should_receive(:content).and_return(metadata_string)
    ds_hash = {ds_name => mock_datastream }
    mock_item = mock("item")
    mock_item.should_receive(:datastreams_in_fedora).and_return(ds_hash)
    mock_item.should_receive(:datastreams).and_return(ds_hash)
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
    mock_item.should_receive(:datastreams_in_fedora).and_return(ds_hash)
    mock_item.should_receive(:datastreams).never
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
    mock_item.should_receive(:datastreams_in_fedora).and_return(ds_hash)
    mock_item.should_receive(:datastreams).never
    lambda {Dor::SdrIngestService.get_datastream_content(mock_item ,'dummy', 'required')}.should raise_exception
  end


  it "can can export a metadata string to a bag" do
    metadata_string = '<metadata/>'
    filename = 'my-metadata-file.xml'
    bag_dir = File.join(Dor::Config.sdr.local_export_home, @druid)
    bag = LyberUtils::BagitBag.new(bag_dir)
    Dor::SdrIngestService.export_metadata_string(metadata_string, filename, bag)
    expected_file = File.join(bag_dir, 'data', 'metadata', filename)
    File.exist?(expected_file).should eql true
    IO.read(expected_file).chomp.should eql metadata_string
  end

  it "can export the standard datastreams" do
    mock_item = mock("item")
    mock_bag = mock("bag")
    metadata_string = '<metadata/>'
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(mock_item,'contentMetadata','required').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(mock_item,'descMetadata','required').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(mock_item,'identityMetadata','required').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(mock_item,'provenanceMetadata','required').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(mock_item,'relationshipMetadata','required').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(mock_item,'technicalMetadata','required').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(mock_item,'sourceMetadata','optional').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:get_datastream_content).with(mock_item,'rightsMetadata','optional').once.and_return(metadata_string)
    Dor::SdrIngestService.should_receive(:export_metadata_string).exactly(8).times
    Dor::SdrIngestService.add_metadata_datastreams(mock_item, mock_bag)
  end

end