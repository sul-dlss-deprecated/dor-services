# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Item do
  describe '#to_solr' do
    subject(:doc) { item.to_solr }

    let(:item) { described_class.new(pid: 'foo:123') }

    before { allow(Dor::Config.workflow.client).to receive(:milestones).and_return([]) }

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

  describe '#workflows' do
    let(:item) { instantiate_fixture('druid:ab123cd4567', described_class) }

    before do
      stub_config
      item.contentMetadata.content = '<contentMetadata/>'
    end

    it 'has a workflows datastream and workflows shortcut method' do
      expect(item.datastreams['workflows']).to be_a(Dor::WorkflowDs)
      expect(item.workflows).to eq(item.datastreams['workflows'])
    end

    it 'loads its content directly from the workflow service' do
      expect(Dor::Config.workflow.client).to receive(:all_workflows_xml).with('druid:ab123cd4567').and_return('<workflows/>')
      expect(item.workflows.content).to eq('<workflows/>')
    end

    it 'is able to invalidate the cache of its content' do
      expect(Dor::Config.workflow.client).to receive(:all_workflows_xml).with('druid:ab123cd4567').and_return('<workflows/>')
      expect(item.workflows.content).to eq('<workflows/>')
      expect(item.workflows.content).to eq('<workflows/>') # should be cached copy
      expect(Dor::Config.workflow.client).to receive(:all_workflows_xml).with('druid:ab123cd4567').and_return('<workflows>with some data</workflows>')
      # pass refresh flag and should be refreshed copy
      expect(item.workflows.content(true)).to eq('<workflows>with some data</workflows>')
      expect(item.workflows.content).to eq('<workflows>with some data</workflows>')
    end
  end
end
