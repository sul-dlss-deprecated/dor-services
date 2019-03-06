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

    # @return [Array<Dor::WorkflowDocument>]
    def workflows
      resource.workflows.workflows
    end
  end
end
