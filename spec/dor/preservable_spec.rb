require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class PreservableItem < ActiveFedora::Base
  include Dor::Preservable
  include Dor::Processable
end

describe Dor::Preservable do

  let(:item) { instantiate_fixture('druid:ab123cd4567', PreservableItem) }

  let(:workflow_id) { 'accessionWF' }

  let(:event_text) { 'DOR Common Accessioning' }

  before(:each) { stub_config   }
  after(:each)  { unstub_config }

  describe "provenanceMetadata" do

    it "builds the provenanceMetadata datastream" do
      item.datastreams['provenanceMetadata'].ng_xml.to_s.should be_equivalent_to('<xml/>')
      item.build_provenanceMetadata_datastream('workflow_id', 'event_text')
      item.datastreams['provenanceMetadata'].ng_xml.to_s.should_not be_equivalent_to('<xml/>')
    end

    it "generates workflow provenance" do
      druid = 'druid:aa123bb4567'
      obj = PreservableItem.new
      obj.stub(:pid) { druid }
      obj.inner_object.stub(:repository).and_return(double('frepo').as_null_object)

      obj.build_provenanceMetadata_datastream(workflow_id, event_text)
      wp_xml = obj.datastreams['provenanceMetadata'].ng_xml
      wp_xml.should be_instance_of(Nokogiri::XML::Document)
      wp_xml.root.name.should eql('provenanceMetadata')
      wp_xml.root[:objectId].should eql(druid)
      agent = wp_xml.xpath('/provenanceMetadata/agent').first
      agent.name.should eql('agent')
      agent[:name].should eql('DOR')
      what = agent.first_element_child()
      what.name.should eql('what')
      what[:object].should eql(druid)
      event = what.first_element_child()
      event.name.should eql('event')
      event[:who].should eql("DOR-#{workflow_id}")
      event.content.should eql(event_text)
    end

  end

  it "builds the technicalMetadata datastream" do
    Dor::TechnicalMetadataService.should_receive(:add_update_technical_metadata).with(item)
    item.build_technicalMetadata_datastream('technicalMetadata')
  end

  it "exports object for sdr ingest" do
    Dor::SdrIngestService.should_receive(:transfer).with(item, nil)
    item.sdr_ingest_transfer(nil)
  end

end
