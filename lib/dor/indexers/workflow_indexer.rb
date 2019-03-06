# frozen_string_literal: true

module Dor
  # Indexes the objects position in workflows
  class WorkflowIndexer
    WORKFLOW_SOLR = 'wf_ssim'
    WORKFLOW_WPS_SOLR = 'wf_wps_ssim'
    WORKFLOW_WSP_SOLR = 'wf_wsp_ssim'
    WORKFLOW_SWP_SOLR = 'wf_swp_ssim'
    WORKFLOW_STATUS_SOLR = 'workflow_status_ssim'

    ERROR_OMISSION = '... (continued)'
    private_constant :ERROR_OMISSION

    # see https://lucene.apache.org/core/7_3_1/core/org/apache/lucene/util/BytesRefHash.MaxBytesLengthExceededException.html
    MAX_ERROR_LENGTH = 32_768 - 2 - ERROR_OMISSION.length
    private_constant :MAX_ERROR_LENGTH

    # @param [Dor::WorkflowDocument] document the workflow document to index
    def initialize(document:)
      @document = document
    end

    # @return [Hash] the partial solr document for the workflow document
    def to_solr
      {}.tap do |solr_doc|
        wf_name = document.workflowId.first

        solr_doc[WORKFLOW_SOLR] = [wf_name]
        solr_doc[WORKFLOW_WPS_SOLR] = [wf_name]
        solr_doc[WORKFLOW_WSP_SOLR] = [wf_name]
        solr_doc[WORKFLOW_SWP_SOLR] = []

        errors = processes.count(&:error?)

        repo = document.repository.first
        solr_doc[WORKFLOW_STATUS_SOLR] = [[wf_name, workflow_status, errors, repo].join('|')]

        processes.each do |process|
          next unless process.status.present?

          # add a record of the robot having operated on this item, so we can track robot activity
          if !process.date_time.blank? && process.status && (process.status == 'completed' || process.status == 'error')
            solr_doc["wf_#{wf_name}_#{process.name}_dttsi"] = Time.parse(process.date_time).utc.iso8601
          end

          index_error_message(solr_doc, wf_name, process)

          # workflow name, process status then process name
          solr_doc[WORKFLOW_WSP_SOLR] += ["#{wf_name}:#{process.status}", "#{wf_name}:#{process.status}:#{process.name}"]

          # workflow name, process name then process status
          solr_doc[WORKFLOW_WPS_SOLR] += ["#{wf_name}:#{process.name}", "#{wf_name}:#{process.name}:#{process.status}"]

          # process status, workflowname then process name
          solr_doc[WORKFLOW_SWP_SOLR] += [process.status.to_s, "#{process.status}:#{wf_name}", "#{process.status}:#{wf_name}:#{process.name}"]
          next unless process.state != process.status

          solr_doc[WORKFLOW_WSP_SOLR] += ["#{wf_name}:#{process.state}:#{process.name}"]
          solr_doc[WORKFLOW_WPS_SOLR] += ["#{wf_name}:#{process.name}:#{process.state}"]

          solr_doc[WORKFLOW_SWP_SOLR] += [process.state.to_s, "#{process.state}:#{wf_name}", "#{process.state}:#{wf_name}:#{process.name}"]
        end
      end
    end

    private

    attr_reader :document
    delegate :processes, to: :document

    def workflow_status
      return 'empty' if processes.empty?

      workflow_should_show_completed?(processes) ? 'completed' : 'active'
    end

    def workflow_should_show_completed?(processes)
      processes.all? { |p| ['skipped', 'completed', '', nil].include?(p.status) }
    end

    # index the error message without the druid so we hopefully get some overlap
    # truncate to avoid org.apache.lucene.util.BytesRefHash$MaxBytesLengthExceededException
    def index_error_message(solr_doc, wf_name, process)
      return unless process.error_message

      error_message = "#{wf_name}:#{process.name}:#{process.error_message}".truncate(MAX_ERROR_LENGTH, omission: ERROR_OMISSION)
      add_solr_value(solr_doc, 'wf_error', error_message, WF_SOLR_TYPE, WF_SOLR_ATTRS)
    end
  end
end
