# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Item do
  describe '#to_solr' do
    subject(:doc) { item.to_solr }

    let(:item) { described_class.new(pid: 'foo:123') }

    let(:wf_indexer) { instance_double(Dor::WorkflowsIndexer, to_solr: {}) }
    let(:process_indexer) { instance_double(Dor::ProcessableIndexer, to_solr: {}) }

    before do
      allow(Dor::WorkflowsIndexer).to receive(:new).and_return(wf_indexer)
      allow(Dor::ProcessableIndexer).to receive(:new).and_return(process_indexer)
    end

    it { is_expected.to include 'active_fedora_model_ssi' => 'Dor::Item' }
  end

  describe 'contentMetadata' do
    let(:item) { described_class.new(pid: 'foo:123') }

    it 'has a contentMetadata datastream' do
      expect(item.contentMetadata).to be_a(Dor::ContentMetadataDS)
    end
  end

  describe 'the dsLocation for workflow' do
    let(:obj) { described_class.new }
    before do
      allow(Dor::Config.workflow.client).to receive(:all_workflows_xml).and_return('<workflows />')
      allow(Dor::SuriService).to receive(:mint_id).and_return('changeme:1231231')
      allow(Dor::Config.suri).to receive(:mint_ids).and_return(true)
      allow(obj).to receive(:update_index)
      obj.save!
    end

    let(:reloaded) { described_class.find(obj.pid) }
    let(:workflows) { reloaded.workflows }

    it 'is set automatically' do
      expect(workflows.dsLocation).to eq 'https://workflow.example.edu/dor/objects/changeme:1231231/workflows'
      expect(workflows.mimeType).to eq 'application/xml'
    end
  end
end
