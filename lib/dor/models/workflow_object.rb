require 'dor/datastreams/workflow_definition_ds'

module Dor
  class WorkflowObject < ::ActiveFedora::Base
    include Identifiable
    
    has_object_type 'workflow'
    has_metadata :name => "workflowDefinition", :type => Dor::WorkflowDefinitionDs, :label => 'Workflow Definition'

    def self.find_by_name(name, opts={})
      Dor.find_all(%{objectType_t:"#{self.object_type}" objProfile_objLabel_s:"#{name}"}, opts).first
    end
    
    def definition
      datastreams['workflowDefinition']
    end
    
    def graph *args
      self.definition.graph *args
    end
    
  end
end