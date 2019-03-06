# frozen_string_literal: true

module Dor
  # Indexes the objects position in workflows
  class WorkflowIndexer
    include SolrDocHelper

    # @param [Dor::WorkflowDocument] document the workflow document to index
    def initialize(document:)
      @document = document
    end

    # @return [Hash] the partial solr document for the workflow document
    def to_solr
      document.to_solr
    end

    private

    attr_reader :document
  end
end
