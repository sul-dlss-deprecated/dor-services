require 'spec_helper'

describe Dor::WorkflowObject do
  describe '.initial_workflow' do
    it 'caches the intial workflow xml for subsequent requests' do
      wobj = double('workflow_object').as_null_object
      expect(Dor::WorkflowObject).to receive(:find_by_name).once.and_return(wobj)

      # First call, object not in cache
      Dor::WorkflowObject.initial_workflow('accessionWF')
      # Second call, object in cache
      expect(Dor::WorkflowObject.initial_workflow('accessionWF')).to eq(wobj)
    end
  end

  describe '#to_solr' do
    before(:each) { stub_config   }
    after(:each)  { unstub_config }

    before :each do
      @item = instantiate_fixture('druid:ab123cd4567', Dor::WorkflowObject)
      @item.workflowDefinition.content = '<workflow-def id="accessionWF"/>'
    end

    it 'indexes the number of archived objects for the workflow' do
      expect(Dor::WorkflowService).to receive(:count_archived_for_workflow).and_return(5)
      expect(@item.to_solr).to include 'accessionWF_archived_isi' => 5
    end
  end

end
