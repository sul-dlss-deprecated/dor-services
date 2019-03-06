# frozen_string_literal: true

module Dor
  # Represents that part of the solr document that holds workflow data
  class WorkflowSolrDocument
    WORKFLOW_SOLR = 'wf_ssim'
    WORKFLOW_WPS_SOLR = 'wf_wps_ssim'
    WORKFLOW_WSP_SOLR = 'wf_wsp_ssim'
    WORKFLOW_SWP_SOLR = 'wf_swp_ssim'
    WORKFLOW_ERROR_SOLR = 'wf_error_ssim'
    WORKFLOW_STATUS_SOLR = 'workflow_status_ssim'

    KEYS_TO_MERGE = [
      WORKFLOW_SOLR,
      WORKFLOW_WPS_SOLR,
      WORKFLOW_WSP_SOLR,
      WORKFLOW_SWP_SOLR,
      WORKFLOW_STATUS_SOLR,
      WORKFLOW_ERROR_SOLR
    ].freeze

    def initialize
      @data = empty_document
      yield self if block_given?
    end

    def to_h
      KEYS_TO_MERGE.each { |k| data[k].uniq! }
      data
    end

    delegate :except, :[], to: :data

    # @param [WorkflowSolrDocument] doc
    def merge!(doc)
      # This is going to get the date fields, e.g. `wf_assemblyWF_jp2-create_dttsi'
      @data.merge!(doc.except(*KEYS_TO_MERGE))

      # Combine the non-unique fields together
      KEYS_TO_MERGE.each do |k|
        data[k] += doc[k]
      end
    end

    private

    attr_reader :data

    def empty_document
      KEYS_TO_MERGE.each_with_object({}) { |k, obj| obj[k] = [] }
    end
  end
end
