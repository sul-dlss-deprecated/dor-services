require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class ProcessableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
  include Dor::Versionable
  include Dor::Describable
end

class ProcessableOnlyItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
end

describe Dor::Processable do

  before(:each) { stub_config   }
  after(:each)  { unstub_config }

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

  context "build_datastream()" do

    before(:each) do
      # Paths to two files with the same content.
      f1 = "workspace/ab/123/cd/4567/ab123cd4567/metadata/descMetadata.xml"
      f2 = "workspace/ab/123/cd/4567/desc_metadata.xml"
      @dm_filename = File.join(@fixture_dir, f1)  # Path used inside build_datastream().
      @dm_fixture_xml = read_fixture(f2)          # Path to fixture.
      @dm_builder_xml = @dm_fixture_xml.sub(/FROM_FILE/, 'FROM_BUILDER')
    end

    context "datastream exists as a file" do

      before(:each) do
        @item.stub(:find_metadata_file).and_return(@dm_filename)
        File.stub(:read).and_return(@dm_fixture_xml)
      end

      it "file newer than datastream: should read content from file" do
        t = Time.now
        File.stub(:mtime).and_return(t)
        @item.descMetadata.stub(:createDate).and_return(t - 99)
        xml = @dm_fixture_xml
        @item.descMetadata.ng_xml.should_not be_equivalent_to(xml)
        @item.build_datastream('descMetadata', true)
        @item.descMetadata.ng_xml.should be_equivalent_to(xml)
        @item.descMetadata.ng_xml.should_not be_equivalent_to(@dm_builder_xml)
      end

      it "file older than datastream: should use the builder" do
        t = Time.now
        File.stub(:mtime).and_return(t - 99)
        @item.descMetadata.stub(:createDate).and_return(t)
        xml = @dm_builder_xml
        @item.stub(:fetch_descMetadata_datastream).and_return(xml)
        @item.descMetadata.ng_xml.should_not be_equivalent_to(xml)
        @item.build_datastream('descMetadata', true)
        @item.descMetadata.ng_xml.should be_equivalent_to(xml)
        @item.descMetadata.ng_xml.should_not be_equivalent_to(@dm_fixture_xml)
      end

    end

    context "datastream does not exist as a file" do

      before(:each) do
        @item.stub(:find_metadata_file).and_return(nil)
      end

      it "should use the datastream builder" do
        xml = @dm_builder_xml
        @item.stub(:fetch_descMetadata_datastream).and_return(xml)
        @item.descMetadata.ng_xml.should_not be_equivalent_to(xml)
        @item.build_datastream('descMetadata')
        @item.descMetadata.ng_xml.should be_equivalent_to(xml)
        @item.descMetadata.ng_xml.should_not be_equivalent_to(@dm_fixture_xml)
      end

      it 'should raise an exception if required datastream cannot be generated' do
        # Fails because there is no build_contentMetadata_datastream() method.
        expect { @item.build_datastream('contentMetadata', false, true) }.to raise_error
      end

    end

  end

  describe 'to_solr' do
    before :each do
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
		</lifecycle>'
		dsxml='
      <versionMetadata objectId="druid:ab123cd4567">
        <version versionId="1" tag="1.0.0">
          <description>Initial version</description>
        </version>
        <version versionId="2" tag="2.0.0">
          <description>Replacing main PDF</description>
        </version>
        <version versionId="3" tag="2.1.0">
          <description>Fixed title typo</description>
        </version>
        <version versionId="4" tag="2.2.0">
          <description>Another typo</description>
        </version>
      </versionMetadata>
    '

      xml=Nokogiri::XML(xml)
  		@lifecycle_vals=[]
  		Dor::WorkflowService.stub(:query_lifecycle).and_return(xml)
  		Dor::Workflow::Document.any_instance.stub(:to_solr).and_return(nil)
  		@versionMD = Dor::VersionMetadataDS.from_xml(dsxml)
  		#@versionMD=mock(Dor::VersionMetadataDS)
  		#@versionMD.stub(:current_version_id).and_return(4)
    end
  	it 'should include the semicolon delimited version, an earliest published date and a status' do
  		@item.stub(:versionMetadata).and_return(@versionMD)
  		solr_doc=@item.to_solr
  		lifecycle=solr_doc['lifecycle_display']
  		#lifecycle_display should have the semicolon delimited version
  		lifecycle.include?("published:2012-01-27T05:06:54Z;2").should == true
  		#published date should be the first published date
  		solr_doc['published_dt'].should == solr_doc['published_earliest_dt']
  		solr_doc['status_display'].first.should == 'v4 In accessioning (described, published)'
  		solr_doc['version_opened_facet'].first.should == '2012-11-07'
  	end
  	it 'should skip the versioning related steps if the item isnt versionable' do
  		@item = instantiate_fixture('druid:ab123cd4567', ProcessableOnlyItem)
  		#@item.stub(:versionMetadata).and_return(@versionMD)
  		solr_doc=@item.to_solr
  		lifecycle=solr_doc['lifecycle_display']
  		#lifecycle_display should have the semicolon delimited version
  		lifecycle.include?("published:2012-01-27T05:06:54Z;2").should == true
  		#published date should be the first published date
  		solr_doc['published_dt'].should == solr_doc['published_earliest_dt']
  		solr_doc['status_display'].first.should == 'v1 In accessioning (described, published)'
  		solr_doc['version_opened_facet'].nil?.should == true
	  end
	  it 'should create a last_modified_day field' do
      @item = instantiate_fixture('druid:ab123cd4567', ProcessableOnlyItem)
  		@item.stub(:versionMetadata).and_return(@versionMD)
  		solr_doc=@item.to_solr
  		#the facet field should have a date in it.
  		solr_doc['last_modified_day_facet'].length.should == 1
    end
    it 'should create a version field for each version, including the version number, tag and description' do
      @item = instantiate_fixture('druid:ab123cd4567', ProcessableOnlyItem)
  		@item.stub(:versionMetadata).and_return(@versionMD)
  		solr_doc=@item.to_solr
  		#the facet field should have a date in it.
  		solr_doc['versions_display'].length.should > 1
  		solr_doc['versions_display'].include?("4;2.2.0;Another typo").should == true
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
  		@item.status.should == 'v4 In accessioning (described, published)'
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
  		@item.status.should == 'v3 In accessioning (described, published)'
  	end
  end
end
