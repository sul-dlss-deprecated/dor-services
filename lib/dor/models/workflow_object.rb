require 'dor/datastreams/workflow_definition_ds'

module Dor
  class WorkflowObject < Dor::Abstract
    @@xml_cache  = {}
    @@repo_cache = {}

    has_object_type 'workflow'
    has_metadata :name => 'workflowDefinition', :type => Dor::WorkflowDefinitionDs, :label => 'Workflow Definition'

    def self.find_by_name(name)
      Dor::WorkflowObject.where(Solrizer.solr_name('workflow_name', :symbol) => name).first
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

    def generate_initial_workflow
      datastreams['workflowDefinition'].initial_workflow
    end

    alias_method :generate_intial_workflow, :generate_initial_workflow

    # Searches DOR for the workflow definition object.  It then caches the workflow repository and xml
    # @param [String] name the name of the workflow
    # @return [Object] a Dor::xxxx object, e.g. a Dor::Item object
    def self.find_and_cache_workflow_xml_and_repo(name)
      wobj = find_by_name(name)
      raise "Failed to find workflow via find_by_name('#{name}')" if wobj.nil?
      @@repo_cache[name] = wobj.definition.repo
      @@xml_cache[name]  = wobj.generate_initial_workflow
      wobj
    end

  end
end
