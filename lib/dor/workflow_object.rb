require 'datastreams/workflow_definition_ds'

module Dor

  class WorkflowObject < Base
    has_metadata :name => "workflowDefinition", :type => WorkflowDefinitionDs

    def definition
      datastreams['workflowDefinition']
    end
  end
  
end