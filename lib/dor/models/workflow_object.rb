require 'dor/datastreams/workflow_definition_ds'

module Dor
  class WorkflowObject < ::ActiveFedora::Base
    include Identifiable
    include SolrDocHelper
    include Governable
    @@xml_cache = {}
    @@repo_cache = {}

    has_object_type 'workflow'
    has_metadata :name => 'workflowDefinition', :type => Dor::WorkflowDefinitionDs, :label => 'Workflow Definition'

    def self.find_by_name(name, opts = {})
      Dor.find_all(%{#{Solrizer.solr_name 'objectType', :symbol}:"#{object_type}" #{Solrizer.solr_name 'workflow_name', :symbol}:"#{name}"}, opts).first
    end

    # Searches for the workflow definition object in DOR, then
    # returns an object's initial workflow as defined in the worfklowDefinition datastream
    # It will cache the result for subsequent requests
    # @param [String] name the name of the workflow
    # @return [String] the initial workflow xml
    def self.initial_workflow(name)
      return @@xml_cache[name] if @@xml_cache.include?(name)

      find_and_cache_workflow_xml_and_repo name
      @@xml_cache[name]
    end

    # Returns the repository attribute from the workflow definition
    # It will cache the result for subsequent requests
    # @param [String] name the name of the workflow
    # @return [String] the initial workflow xml
    def self.initial_repo(name)
      return @@repo_cache[name] if @@repo_cache.include?(name)

      find_and_cache_workflow_xml_and_repo name
      @@repo_cache[name]
    end

    def definition
      datastreams['workflowDefinition']
    end

    def graph(*args)
      definition.graph *args
    end

    def to_solr(solr_doc = {}, *args)
      super solr_doc, *args
      client = Dor::WorkflowService.workflow_resource
      xml = client["workflow_archive?repository=#{definition.repo}&workflow=#{definition.name}&count-only=true"].get
      count = Nokogiri::XML(xml).at_xpath('/objects/@count').value
      solr_doc["#{definition.name}_archived_isi"] = count
      solr_doc
    end

    def generate_initial_workflow
      datastreams['workflowDefinition'].initial_workflow
    end

    alias_method :generate_intial_workflow, :generate_initial_workflow

    # Searches DOR for the workflow definition object.  It then caches the workflow repository and xml
    # @param [String] name the name of the workflow
    def self.find_and_cache_workflow_xml_and_repo(name)
      wobj = find_by_name(name)
      wf_xml = wobj.generate_initial_workflow
      @@repo_cache[name] = wobj.definition.repo
      @@xml_cache[name] = wf_xml
    end

  end
end
