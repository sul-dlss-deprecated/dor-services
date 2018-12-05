# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Item do
  describe '#to_solr' do
    subject(:doc) { item.to_solr }
    let(:item) { described_class.new(pid: 'foo:123') }

    before { allow(Dor::Config.workflow.client).to receive(:get_milestones).and_return([]) }

    it { is_expected.to include 'active_fedora_model_ssi' => 'Dor::Item' }
  end

  describe 'the dsLocation for workflow' do
    let(:obj) { described_class.new }
    before do
      allow(Dor::SuriService).to receive(:mint_id).and_return('changeme:1231231')
      allow(Dor::Config.suri).to receive(:mint_ids).and_return(true)
      allow(obj).to receive(:update_index)
      obj.save!
    end
    let(:reloaded) { Dor::Item.find(obj.pid) }
    let(:workflows) { reloaded.workflows }

    it 'is set automatically' do
      expect(workflows.dsLocation).to eq 'http://example.edu/workflow/dor/objects/changeme:1231231/workflows'
      expect(workflows.mimeType).to eq 'application/xml'
    end
  end

  describe '#build_technicalMetadata_datastream' do
    let(:item) { described_class.new(pid: 'foo:123') }

    it 'builds the technicalMetadata datastream if the object is an item' do
      expect(Dor::TechnicalMetadataService).to receive(:add_update_technical_metadata).with(item)
      item.build_technicalMetadata_datastream('technicalMetadata')
    end
  end
end
