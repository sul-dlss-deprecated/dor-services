# frozen_string_literal: true

module Dor
  # Indexes the objects position in workflows
  class WorkflowIndexer
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
      WorkflowSolrDocument.new do |solr_doc|
        solr_doc.name = wf_name
        errors = processes.count(&:error?)
        solr_doc.status = [wf_name, workflow_status, errors, repo].join('|')

        processes.each do |process|
          index_process(solr_doc, wf_name, process)
        end
      end
    end

    private

    attr_reader :document
    delegate :processes, to: :document

    def wf_name
      @wf_name ||= document.workflowId.first
    end

    def repo
      document.repository.first
    end

    def index_process(solr_doc, wf_name, process)
      return unless process.status.present?

      # add a record of the robot having operated on this item, so we can track robot activity
      solr_doc.add_process_time(wf_name, process.name, Time.parse(process.date_time)) if process_has_time?(process)

      index_error_message(solr_doc, wf_name, process)

      # workflow name, process status then process name
      solr_doc.add_wsp("#{wf_name}:#{process.status}", "#{wf_name}:#{process.status}:#{process.name}")

      # workflow name, process name then process status
      solr_doc.add_wps("#{wf_name}:#{process.name}", "#{wf_name}:#{process.name}:#{process.status}")

      # process status, workflowname then process name
      solr_doc.add_swp(process.status.to_s, "#{process.status}:#{wf_name}", "#{process.status}:#{wf_name}:#{process.name}")
      return if process.state == process.status

      solr_doc.add_wsp("#{wf_name}:#{process.state}:#{process.name}")
      solr_doc.add_wps("#{wf_name}:#{process.name}:#{process.state}")
      solr_doc.add_swp(process.state.to_s, "#{process.state}:#{wf_name}", "#{process.state}:#{wf_name}:#{process.name}")
    end

    def process_has_time?(process)
      !process.date_time.blank? && process.status && (process.status == 'completed' || process.status == 'error')
    end

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

      solr_doc.error = "#{wf_name}:#{process.name}:#{process.error_message}".truncate(MAX_ERROR_LENGTH, omission: ERROR_OMISSION)
    end
  end
end
