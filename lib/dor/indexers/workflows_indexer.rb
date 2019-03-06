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
      empty_doc.tap do |solr_doc|
        workflows.each do |wf|
          doc = WorkflowIndexer.new(document: wf).to_solr

          # This is going to get the date fields, e.g. `wf_assemblyWF_jp2-create_dttsi'
          solr_doc.merge!(doc.except(*keys_to_merge))

          # Combine the non-unique fields together
          keys_to_merge.each do |k|
            solr_doc[k] += doc[k]
          end
        end

        keys_to_merge.each { |k| solr_doc[k].uniq! }
      end
    end

    private

    def empty_doc
      keys_to_merge.each_with_object({}) { |k, obj| obj[k] = [] }
    end

    def keys_to_merge
      [
        WorkflowIndexer::WORKFLOW_SOLR,
        WorkflowIndexer::WORKFLOW_WPS_SOLR,
        WorkflowIndexer::WORKFLOW_WSP_SOLR,
        WorkflowIndexer::WORKFLOW_SWP_SOLR,
        WorkflowIndexer::WORKFLOW_STATUS_SOLR
      ]
    end

    # @return [Array<Dor::WorkflowDocument>]
    def workflows
      resource.workflows.workflows
    end
  end
end
