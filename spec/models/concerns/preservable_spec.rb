# frozen_string_literal: true

require 'spec_helper'

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

  describe 'provenanceMetadata' do
    it 'builds the provenanceMetadata datastream' do
      expect(item.datastreams['provenanceMetadata'].ng_xml.to_s).to be_equivalent_to('<xml/>')
      item.build_provenanceMetadata_datastream('workflow_id', 'event_text')
      expect(item.datastreams['provenanceMetadata'].ng_xml.to_s).not_to be_equivalent_to('<xml/>')
    end

    it 'generates workflow provenance' do
      druid = 'druid:aa123bb4567'
      obj = PreservableItem.new
      allow(obj).to receive(:pid) { druid }
      allow(obj.inner_object).to receive(:repository).and_return(double('frepo').as_null_object)

      obj.build_provenanceMetadata_datastream(workflow_id, event_text)
      wp_xml = obj.datastreams['provenanceMetadata'].ng_xml
      expect(wp_xml).to be_instance_of(Nokogiri::XML::Document)
      expect(wp_xml.root.name).to eql('provenanceMetadata')
      expect(wp_xml.root[:objectId]).to eql(druid)
      agent = wp_xml.xpath('/provenanceMetadata/agent').first
      expect(agent.name).to eql('agent')
      expect(agent[:name]).to eql('DOR')
      what = agent.first_element_child
      expect(what.name).to eql('what')
      expect(what[:object]).to eql(druid)
      event = what.first_element_child
      expect(event.name).to eql('event')
      expect(event[:who]).to eql("DOR-#{workflow_id}")
      expect(event.content).to eql(event_text)
    end
  end

  it 'builds the technicalMetadata datastream if the object is an item' do
    allow(item).to receive(:is_a?).with(Dor::Item).and_return(true)
    expect(Dor::TechnicalMetadataService).to receive(:add_update_technical_metadata).with(item)
    item.build_technicalMetadata_datastream('technicalMetadata')
  end

  it 'does not build the technicalMetadata datastream if the object is not an item' do
    allow(item).to receive(:is_a?).with(Dor::Item).and_return(false)
    expect(Dor::TechnicalMetadataService).not_to receive(:add_update_technical_metadata)
    item.build_technicalMetadata_datastream('technicalMetadata')
  end

  it 'exports object for sdr ingest' do
    expect(Dor::SdrIngestService).to receive(:transfer).with(item, nil)
    item.sdr_ingest_transfer(nil)
  end
end
