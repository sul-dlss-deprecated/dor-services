require 'dor/datastreams/workflow_definition_ds'

module Dor
  class WorkflowObject < ::ActiveFedora::Base
    include Identifiable
    
    has_object_type 'workflow'
    has_metadata :name => "workflowDefinition", :type => Dor::WorkflowDefinitionDs, :label => 'Workflow Definition'

    def self.find_by_name(name)
      resp = Dor::SearchService.gsearch :q => %{object_type_field:workflow dc_title_field:"#{name}"}
      doc = resp['response']['docs'].first
      if doc.nil?
        nil
      else
        self.load_instance(doc['id'].to_s)
      end
    end
    
    def definition
      datastreams['workflowDefinition']
    end
    
    def graph *args
      self.definition.graph *args
    end
    
  end
end