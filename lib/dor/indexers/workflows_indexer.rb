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
          doc = WorkflowIndexer.new(workflow: wf).to_solr
          combined_doc.merge!(doc)
        end
      end.to_h
    end

    private

    # @return [Array<Workflow::Response::Workflow>]
    def workflows
      all_workflows.workflows
    end

    # @return [Workflow::Response::Workflows]
    def all_workflows
      @all_workflows ||= Dor::Config.workflow.client.workflow_routes.all_workflows pid: resource.pid
    end
  end
end
