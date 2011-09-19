require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'dor/provenance_metadata_service'

describe Dor::ProvenanceMetadataService do

  before :all do
    @druid = 'druid:aa123bb4567'
    @workflow_id = 'accessionWF'
    @event_text = "DOR Common Accessioning"
    @wp_xml = Dor::ProvenanceMetadataService.create_workflow_provenance(@druid, @workflow_id, @event_text)
    @fixtures = File.dirname(__FILE__) + '/../fixtures'
    @old_provenance = IO.read(File.join(@fixtures,'old_provenance_metadata.xml'))
  end


  it "can generate workflow_provenance" do
    @wp_xml.should be_instance_of(Nokogiri::XML::Document)
    @wp_xml.root.name.should eql('provenanceMetadata')
    @wp_xml.root[:objectId].should eql(@druid)
    agent = @wp_xml.xpath('/provenanceMetadata/agent').first
    agent.name.should eql('agent')
    agent[:name].should eql('DOR')
    what = agent.first_element_child()
    what.name.should eql('what')
    what[:object].should eql(@druid)
    event = what.first_element_child()
    event.name.should eql('event')
    event[:who].should eql("DOR-#{@workflow_id}")
    event.content.should eql(@event_text)
  end

  it "can retrieve fixtures/old_provenance" do
    old_provenance_xml = Nokogiri::XML(@old_provenance)
    old_provenance_xml.should be_instance_of(Nokogiri::XML::Document)
    old_provenance_xml.root.name.should eql('provenanceMetadata')
  end

  it "can append new provenance to old provenance" do
    new_xml = Dor::ProvenanceMetadataService.update_provenance(@old_provenance, @wp_xml)
    new_xml.xpath('//agent').size.should eql(3)
    new_agent = new_xml.xpath('//agent').last
    what = new_agent.first_element_child()
    what.name.should eql('what')
    what[:object].should eql(@druid)
    event = what.first_element_child()
    event.name.should eql('event')
    event[:who].should eql("DOR-#{@workflow_id}")
    event.content.should eql(@event_text)
  end


end