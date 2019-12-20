# frozen_string_literal: true

require 'dor/datastreams/workflow_definition_ds'

module Dor
  # @deprecated
  class WorkflowObject < Dor::Abstract
    has_object_type 'workflow'
    has_metadata name: 'workflowDefinition', type: Dor::WorkflowDefinitionDs, label: 'Workflow Definition'

    self.resource_indexer = CompositeIndexer.new(
      DataIndexer,
      DescribableIndexer,
      IdentifiableIndexer,
      ProcessableIndexer,
      WorkflowsIndexer
    )

    def self.find_by_name(name)
      Dor::WorkflowObject.where(Solrizer.solr_name('workflow_name', :symbol) => name).first
    end

    # @return [Dor::WorkflowDefinitionDs]
    def definition
      datastreams['workflowDefinition']
    end
  end
end
