# frozen_string_literal: true

module Dor
  # Indexes the objects position in workflows
  class WorkflowIndexer
    include SolrDocHelper

    ERROR_OMISSION = '... (continued)'
    private_constant :ERROR_OMISSION

    # see https://lucene.apache.org/core/7_3_1/core/org/apache/lucene/util/BytesRefHash.MaxBytesLengthExceededException.html
    MAX_ERROR_LENGTH = 32_768 - 2 - ERROR_OMISSION.length
    private_constant :MAX_ERROR_LENGTH

    WF_SOLR_TYPE = :string
    private_constant :WF_SOLR_TYPE
    WF_SOLR_ATTRS = [:symbol].freeze
    private_constant :WF_SOLR_ATTRS

    # @param [Dor::WorkflowDocument] document the workflow document to index
    def initialize(document:)
      @document = document
    end

    # @return [Hash] the partial solr document for the workflow document
    def to_solr
      {}.tap do |solr_doc|
        wf_name = document.workflowId.first

        add_solr_value(solr_doc, 'wf',     wf_name, WF_SOLR_TYPE, WF_SOLR_ATTRS)
        add_solr_value(solr_doc, 'wf_wps', wf_name, WF_SOLR_TYPE, WF_SOLR_ATTRS)
        add_solr_value(solr_doc, 'wf_wsp', wf_name, WF_SOLR_TYPE, WF_SOLR_ATTRS)
        errors = processes.count(&:error?)

        repo = document.repository.first
        add_solr_value(solr_doc, 'workflow_status', [wf_name, workflow_status, errors, repo].join('|'), WF_SOLR_TYPE, WF_SOLR_ATTRS)

        processes.each do |process|
          next unless process.status.present?

          # add a record of the robot having operated on this item, so we can track robot activity
          if !process.date_time.blank? && process.status && (process.status == 'completed' || process.status == 'error')
            solr_doc["wf_#{wf_name}_#{process.name}_dttsi"] = Time.parse(process.date_time).utc.iso8601
          end

          index_error_message(solr_doc, wf_name, process)

          add_solr_value(solr_doc, 'wf_wsp', "#{wf_name}:#{process.status}", WF_SOLR_TYPE, WF_SOLR_ATTRS)
          add_solr_value(solr_doc, 'wf_wsp', "#{wf_name}:#{process.status}:#{process.name}", WF_SOLR_TYPE, WF_SOLR_ATTRS)
          add_solr_value(solr_doc, 'wf_wps', "#{wf_name}:#{process.name}", WF_SOLR_TYPE, WF_SOLR_ATTRS)
          add_solr_value(solr_doc, 'wf_wps', "#{wf_name}:#{process.name}:#{process.status}", WF_SOLR_TYPE, WF_SOLR_ATTRS)
          add_solr_value(solr_doc, 'wf_swp', process.status.to_s, WF_SOLR_TYPE, WF_SOLR_ATTRS)
          add_solr_value(solr_doc, 'wf_swp', "#{process.status}:#{wf_name}", WF_SOLR_TYPE, WF_SOLR_ATTRS)
          add_solr_value(solr_doc, 'wf_swp', "#{process.status}:#{wf_name}:#{process.name}", WF_SOLR_TYPE, WF_SOLR_ATTRS)
          next unless process.state != process.status

          add_solr_value(solr_doc, 'wf_wsp', "#{wf_name}:#{process.state}:#{process.name}", WF_SOLR_TYPE, WF_SOLR_ATTRS)
          add_solr_value(solr_doc, 'wf_wps', "#{wf_name}:#{process.name}:#{process.state}", WF_SOLR_TYPE, WF_SOLR_ATTRS)
          add_solr_value(solr_doc, 'wf_swp', process.state.to_s, WF_SOLR_TYPE, WF_SOLR_ATTRS)
          add_solr_value(solr_doc, 'wf_swp', "#{process.state}:#{wf_name}", WF_SOLR_TYPE, WF_SOLR_ATTRS)
          add_solr_value(solr_doc, 'wf_swp', "#{process.state}:#{wf_name}:#{process.name}", WF_SOLR_TYPE, WF_SOLR_ATTRS)
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
