# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::WorkflowObject do
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
