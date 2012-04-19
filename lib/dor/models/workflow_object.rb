require 'dor/datastreams/workflow_definition_ds'

module Dor
  class WorkflowObject < ::ActiveFedora::Base
    include Identifiable
    include Upgradable
    include SolrDocHelper
    
    has_object_type 'workflow'
    has_metadata :name => "workflowDefinition", :type => Dor::WorkflowDefinitionDs, :label => 'Workflow Definition'

    def self.find_by_name(name, opts={})
      Dor.find_all(%{objectType_t:"#{self.object_type}" workflow_name_s:"#{name}"}, opts).first
    end
    
    def definition
      datastreams['workflowDefinition']
    end
    
    def graph *args
      self.definition.graph *args
    end
    
    def to_solr solr_doc=Hash.new, *args
      super solr_doc, *args
      client = Dor::WorkflowService.workflow_resource
      xml = client["workflow_archive?repository=#{definition.repo}&workflow=#{definition.name}&count-only=true"].get
      count = Nokogiri::XML(xml).at_xpath('/objects/@count').value
      add_solr_value(solr_doc,"#{definition.name}_archived",count,:integer,[:displayable])
      solr_doc
    end
  end
end