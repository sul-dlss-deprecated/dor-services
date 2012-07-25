require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class PreservableItem < ActiveFedora::Base
  include Dor::Preservable
  include Dor::Processable
end

describe Dor::Preservable do

  before(:all) { stub_config   }
  after(:all)  { unstub_config }

  before(:each) do
    @item = instantiate_fixture('druid:ab123cd4567', PreservableItem)
  end
  
  it "should build the provenanceMetadata datastream" do
    @item.datastreams['provenanceMetadata'].ng_xml.to_s.should be_equivalent_to('<xml/>')
    @item.build_provenanceMetadata_datastream('workflow_id', 'event_text')
    @item.datastreams['provenanceMetadata'].ng_xml.to_s.should_not be_equivalent_to('<xml/>')
  end

  it "should build the technicalMetadata datastream" do
    Dor::TechnicalMetadataService.should_receive(:add_update_technical_metadata).with(@item)
    @item.build_technicalMetadata_datastream('technicalMetadata')
  end

  it "should export object for sdr ingest" do
    Dor::SdrIngestService.should_receive(:transfer).with(@item, nil)
    @item.sdr_ingest_transfer(nil)
  end

end
