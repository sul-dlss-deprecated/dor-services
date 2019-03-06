# frozen_string_literal: true

module Dor
  # Indexes the objects position in workflows
  class WorkflowsIndexer
    include SolrDocHelper

    attr_reader :resource
    def initialize(resource:)
      @resource = resource
    end

    # @return [Hash] the partial solr document for workflow concerns
    def to_solr
      {}.tap do |solr_doc|
        workflows.each { |wf| solr_doc = wf.to_solr(solr_doc) }
      end
    end

    private

    # @return [Array<Dor::WorkflowDocument>]
    def workflows
      resource.workflows.workflows
    end
  end
end
