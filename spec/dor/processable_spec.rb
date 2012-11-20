require File.expand_path(File.dirname(__FILE__) + '/../spec_helper') 
class ProcessableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
  include Dor::Versionable
end

describe Dor::Processable do
  
  before(:all) { stub_config   }
  after(:all)  { unstub_config }
  
  before :each do
    @item = instantiate_fixture('druid:ab123cd4567', ProcessableItem)
    @item.contentMetadata.content = '<contentMetadata/>'
  end
  
  it "has a workflows datastream" do
    @item.datastreams['workflows'].should be_a(Dor::WorkflowDs)
  end

  it "should load its content directly from the workflow service" do
    Dor::WorkflowService.should_receive(:get_workflow_xml).with('dor','druid:ab123cd4567',nil)
    @item.datastreams['workflows'].content
  end
  
  context "filesystem-based content" do
    before :each do
      @filename = File.join(@fixture_dir, "workspace/ab/123/cd/4567/ab123cd4567/metadata/contentMetadata.xml")
      @content_md = read_fixture("workspace/ab/123/cd/4567/content_metadata.xml")
    end
    
    it "should read datastream content files from the workspace" do
      File.stub(:exists?).with(@filename).and_return(true)
      File.should_not_receive(:exists?).with(/content_metadata\.xml/)
      File.should_receive(:read).with(@filename).and_return(@content_md)
      @item.build_datastream('contentMetadata',true)
      @item.datastreams['contentMetadata'].ng_xml.should be_equivalent_to(@content_md)
    end

    it "should use the datastream builder if the file doesn't exist" do
      File.stub(:exists?).with(/contentMetadata\.xml/).and_return(false)
      File.should_receive(:exists?).with(/content_metadata\.xml/).and_return(true)
      @item.build_datastream('contentMetadata',true)
      @item.datastreams['contentMetadata'].ng_xml.should be_equivalent_to(@content_md)
    end
  end
  describe 'milestones' do
    it 'should build a list of all lifecycle events grouped by version' do
      
    end
  end
  describe 'to_solr' do
  	it 'should include the semicolon delimited version, an earliest published date and a status' do
  		xml='<?xml version="1.0" encoding="UTF-8"?>
      <lifecycle objectId="druid:gv054hp4128">
    <milestone date="2012-01-26T21:06:54-0800" version="2">published</milestone>
    <milestone date="2012-10-29T16:30:07-0700" version="2">opened</milestone>
    <milestone date="2012-11-06T16:18:24-0800" version="2">submitted</milestone>
    <milestone date="2012-11-06T16:19:07-0800" version="2">published</milestone>
    <milestone date="2012-11-06T16:19:10-0800" version="2">accessioned</milestone>
    <milestone date="2012-11-06T16:19:15-0800" version="2">described</milestone>
    <milestone date="2012-11-06T16:21:02-0800">opened</milestone>
    <milestone date="2012-11-06T16:30:03-0800">submitted</milestone>
    <milestone date="2012-11-06T16:35:00-0800">described</milestone>
    <milestone date="2012-11-06T16:59:39-0800" version="3">published</milestone>
    <milestone date="2012-11-06T16:59:39-0800">published</milestone>
		</lifecycle>
      ' 
      xml=Nokogiri::XML(xml)
  		@lifecycle_vals=[]
  		Dor::WorkflowService.stub(:query_lifecycle).and_return(xml)
  		Dor::Workflow::Document.any_instance.stub(:to_solr).and_return(nil)
  		versionMD=mock(Dor::VersionMetadataDS)
  		versionMD.stub(:current_version_id).and_return(4)
  		@item.stub(:versionMetadata).and_return(versionMD)
  		solr_doc=@item.to_solr
  		lifecycle=solr_doc['lifecycle_display']
  		#lifecycle_display should have the semicolon delimited version
  		lifecycle.include?("published:2012-01-27T05:06:54Z;2").should == true
  		#published date should be the first published date
  		solr_doc['published_dt'].should == solr_doc['published_earliest_dt']
  		solr_doc['status_display'].first.should == 'v4 Opened'
  		solr_doc['version_opened_facet'].first.should == '2012-11-07'
  	end
  end
  describe 'status' do
  	it 'should generate a status string' do
  	xml='<?xml version="1.0" encoding="UTF-8"?>
      <lifecycle objectId="druid:gv054hp4128">
    <milestone date="2012-11-06T16:19:15-0800" version="2">described</milestone>
    <milestone date="2012-11-06T16:21:02-0800">opened</milestone>
    <milestone date="2012-11-06T16:30:03-0800">submitted</milestone>
    <milestone date="2012-11-06T16:35:00-0800">described</milestone>
    <milestone date="2012-11-06T16:59:39-0800" version="3">published</milestone>
    <milestone date="2012-11-06T16:59:39-0800">published</milestone>
		</lifecycle>
      ' 
      xml=Nokogiri::XML(xml)
  		@lifecycle_vals=[]
  		Dor::WorkflowService.stub(:query_lifecycle).and_return(xml)
  		Dor::Workflow::Document.any_instance.stub(:to_solr).and_return(nil)
  		versionMD=mock(Dor::VersionMetadataDS)
  		versionMD.stub(:current_version_id).and_return(4)
  		@item.stub(:versionMetadata).and_return(versionMD)
  		@item.status.should == 'v4 Opened'
  	end
  	it 'should generate a status string' do
  	xml='<?xml version="1.0" encoding="UTF-8"?>
      <lifecycle objectId="druid:gv054hp4128">
    <milestone date="2012-11-06T16:19:15-0800" version="2">described</milestone>
    <milestone date="2012-11-06T16:59:39-0800" version="3">published</milestone>
		</lifecycle>
      ' 
      xml=Nokogiri::XML(xml)
  		@lifecycle_vals=[]
  		Dor::WorkflowService.stub(:query_lifecycle).and_return(xml)
  		Dor::Workflow::Document.any_instance.stub(:to_solr).and_return(nil)
  		versionMD=mock(Dor::VersionMetadataDS)
  		versionMD.stub(:current_version_id).and_return(4)
  		@item.stub(:versionMetadata).and_return(versionMD)
  		@item.status.should == 'v3 In process (described, published)'
  	end
  end
end
