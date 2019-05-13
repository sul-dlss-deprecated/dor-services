# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::WorkflowObject do
  describe '.initial_workflow' do
    it 'caches the intial workflow xml for subsequent requests' do
      expect(Deprecation).to receive(:warn).twice
      wobj = double('workflow_object').as_null_object
      expect(described_class).to receive(:find_by_name).once.and_return(wobj)

      # First call, object not in cache
      described_class.initial_workflow('accessionWF')
      # Second call, object in cache
      expect(described_class.initial_workflow('accessionWF')).to eq(wobj)
    end
  end

  # TODO: Move to the DataIndexer spec
  describe '#to_solr' do
    let(:wf_indexer) { instance_double(Dor::WorkflowsIndexer, to_solr: {}) }
    let(:process_indexer) { instance_double(Dor::ProcessableIndexer, to_solr: {}) }
    let(:item) { instantiate_fixture('druid:ab123cd4567', described_class) }

    before do
      allow(Dor::WorkflowsIndexer).to receive(:new).and_return(wf_indexer)
      allow(Dor::ProcessableIndexer).to receive(:new).and_return(process_indexer)
      item.workflowDefinition.content = '<workflow-def id="accessionWF"/>'
    end

    it 'indexes the workflow name' do
      expect(item.to_solr).to include 'workflow_name_ssim' => ['accessionWF']
    end
  end
end
