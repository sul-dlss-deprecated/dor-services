require 'dor/datastreams/workflow_definition_ds'

module Dor
  class WorkflowObject < ::ActiveFedora::Base
    include Identifiable
    include SolrDocHelper
    include Governable
    @@xml_cache = {}

    has_object_type 'workflow'
    has_metadata :name => "workflowDefinition", :type => Dor::WorkflowDefinitionDs, :label => 'Workflow Definition'

    def self.find_by_name(name, opts={})
      Dor.find_all(%{objectType_t:"#{self.object_type}" workflow_name_s:"#{name}"}, opts).first
    end
    
    # Searches for the workflow definition object in DOR, then 
    # returns an object's initial workflow as defined in the worfklowDefinition datastream
    # It will cache the result for subsequent requests
    # @param [String] name the name of the workflow
    # @return [String] the initial workflow xml
    def self.initial_workflow(name)
      return @@xml_cache[name] if(@@xml_cache.include?(name))

      wobj = self.find_by_name(name)
      wf_xml = wobj.generate_intial_workflow
      @@xml_cache[name] = wf_xml
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

    def generate_intial_workflow
      datastreams['workflowDefinition'].initial_workflow
    end

  end
end