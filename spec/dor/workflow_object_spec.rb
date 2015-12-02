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

end
