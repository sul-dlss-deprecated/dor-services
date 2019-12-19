# frozen_string_literal: true

module Dor
  # Indexes the objects position in workflows
  class WorkflowsIndexer
    attr_reader :resource
    def initialize(resource:)
      @resource = resource
    end

    # @return [Hash] the partial solr document for workflow concerns
    def to_solr
      WorkflowSolrDocument.new do |combined_doc|
        workflows.each do |wf|
          doc = WorkflowIndexer.new(document: wf).to_solr
          combined_doc.merge!(doc)
        end
      end.to_h
    end

    private

    # @return [Array<Dor::Workflow::Document>]
    def workflows
      # TODO: this could use the models in dor-workflow-service: https://github.com/sul-dlss/dor-workflow-client/pull/101
      nodeset = Nokogiri::XML(all_workflows_xml).xpath('/workflows/workflow')
      nodeset.map { |wf_node| Workflow::Document.new wf_node.to_xml }
    end

    def all_workflows_xml
      @all_workflows_xml ||= Dor::Config.workflow.client.all_workflows_xml resource.pid
    end
  end
end
