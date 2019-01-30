# frozen_string_literal: true

require 'spec_helper'

describe Dor::WorkflowObject do
  describe '.initial_workflow' do
    it 'caches the intial workflow xml for subsequent requests' do
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
    before { stub_config   }

    after  { unstub_config }

    before do
      @item = instantiate_fixture('druid:ab123cd4567', described_class)
      @item.workflowDefinition.content = '<workflow-def id="accessionWF"/>'
    end

    it 'indexes the workflow name' do
      allow_any_instance_of(Dor::StatusService).to receive(:milestones).and_return([])
      expect(@item.to_solr).to include 'workflow_name_ssim' => ['accessionWF']
    end
  end
end
