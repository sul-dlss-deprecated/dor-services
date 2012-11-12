require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class ProcessableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
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
      xml='<?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
              datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
          <process version="2" elapsed="0.0" archived="true" attempts="1"
              datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
          <process version="2" elapsed="0.0" archived="true" attempts="1"
              datetime="2012-11-06T16:19:02-0800" status="completed" name="provenance-metadata"/>
          <process version="2" elapsed="0.0" archived="true" attempts="1"
              datetime="2012-11-06T16:19:05-0800" status="completed" name="remediate-object"/>
          <process version="2" elapsed="0.0" archived="true" attempts="1"
              datetime="2012-11-06T16:19:06-0800" status="completed" name="shelve"/>
          <process version="2" lifecycle="published" elapsed="0.0" archived="true" attempts="1"
              datetime="2012-11-06T16:19:07-0800" status="completed" name="publish"/>
          <process version="2" elapsed="0.0" archived="true" attempts="1"
              datetime="2012-11-06T16:19:09-0800" status="completed" name="sdr-ingest-transfer"/>
          <process version="2" lifecycle="accessioned" elapsed="0.0" archived="true" attempts="1"
              datetime="2012-11-06T16:19:10-0800" status="completed" name="cleanup"/>
          <process version="2" elapsed="0.0" archived="true" attempts="1"
              datetime="2012-11-06T16:19:13-0800" status="completed" name="rights-metadata"/>
          <process version="2" lifecycle="described" elapsed="0.0" archived="true" attempts="1"
              datetime="2012-11-06T16:19:15-0800" status="completed" name="descriptive-metadata"/>
          <process version="2" elapsed="0.0" archived="true" attempts="2"
              datetime="2012-11-06T16:19:16-0800" status="completed" name="content-metadata"/>
          <process elapsed="0.0" attempts="0" datetime="2012-11-06T16:30:03-0800" status="waiting"
              name="technical-metadata"/>
          <process elapsed="0.0" attempts="0" datetime="2012-11-06T16:30:03-0800" status="waiting"
              name="remediate-object"/>
          <process elapsed="0.0" attempts="0" datetime="2012-11-06T16:30:03-0800" status="waiting"
              name="shelve"/>
          <process lifecycle="published" elapsed="0.0" attempts="0" datetime="2012-11-06T16:30:03-0800"
              status="waiting" name="publish"/>
          <process elapsed="0.0" attempts="0" datetime="2012-11-06T16:30:03-0800" status="waiting"
              name="sdr-ingest-transfer"/>
          <process lifecycle="accessioned" elapsed="0.0" attempts="0" datetime="2012-11-06T16:30:03-0800"
              status="waiting" name="cleanup"/>
          <process elapsed="0.0" attempts="0" datetime="2012-11-06T16:30:03-0800" status="waiting"
              name="content-metadata"/>
          <process elapsed="0.0" attempts="0" datetime="2012-11-06T16:30:03-0800" status="waiting"
              name="rights-metadata"/>
          <process elapsed="0.0" attempts="0" datetime="2012-11-06T16:30:03-0800" status="waiting"
              name="provenance-metadata"/>
          <process lifecycle="described" elapsed="0.0" attempts="0" datetime="2012-11-06T16:30:03-0800"
              status="waiting" name="descriptive-metadata"/>
          <process lifecycle="submitted" elapsed="0.0" attempts="1" datetime="2012-11-06T16:30:03-0800"
              status="completed" name="start-accession"/>
      </workflow>
      '
      Dor::WorkflowService.stub(:get_workflow_xml).and_return(xml)
      puts @item.milestones.inspect
    end
  end
end
