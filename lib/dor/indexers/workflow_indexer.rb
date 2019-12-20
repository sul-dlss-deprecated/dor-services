# frozen_string_literal: true

module Dor
  # Indexes the objects position in workflows
  class WorkflowIndexer
    ERROR_OMISSION = '... (continued)'
    private_constant :ERROR_OMISSION

    # see https://lucene.apache.org/core/7_3_1/core/org/apache/lucene/util/BytesRefHash.MaxBytesLengthExceededException.html
    MAX_ERROR_LENGTH = 32_768 - 2 - ERROR_OMISSION.length
    private_constant :MAX_ERROR_LENGTH

    # @param [Workflow::Response::Workflow] workflow the workflow document to index
    def initialize(workflow:)
      @workflow = workflow
    end

    # @return [Hash] the partial solr document for the workflow document
    def to_solr
      WorkflowSolrDocument.new do |solr_doc|
        definition = Dor::Config.workflow.client.workflow_template(workflow_name)
        solr_doc.name = workflow_name
        processes_names = definition['processes'].map { |p| p['name'] }

        errors = 0 # The error count is used by the Report class in Argo
        processes = processes_names.map do |process_name|
          workflow.process_for_recent_version(name: process_name)
        end
        processes.each do |process|
          index_process(solr_doc, process)
          errors += 1 if process.status == 'error'
        end
        solr_doc.status = [workflow_name, workflow_status(processes), errors, repository].join('|')
      end
    end

    private

    attr_reader :workflow
    delegate :workflow_name, :repository, to: :workflow

    # @param [Workflow::Response::Process] process
    def index_process(solr_doc, process)
      return unless process.status

      # add a record of the robot having operated on this item, so we can track robot activity
      solr_doc.add_process_time(workflow_name, process.name, Time.parse(process.datetime)) if process_has_time?(process)

      index_error_message(solr_doc, process)

      # workflow name, process status then process name
      solr_doc.add_wsp("#{workflow_name}:#{process.status}", "#{workflow_name}:#{process.status}:#{process.name}")

      # workflow name, process name then process status
      solr_doc.add_wps("#{workflow_name}:#{process.name}", "#{workflow_name}:#{process.name}:#{process.status}")

      # process status, workflowname then process name
      solr_doc.add_swp(process.status.to_s, "#{process.status}:#{workflow_name}", "#{process.status}:#{workflow_name}:#{process.name}")
    end

    def process_has_time?(process)
      process.datetime && process.status && (process.status == 'completed' || process.status == 'error')
    end

    def workflow_status(processes)
      return 'empty' if processes.empty?

      workflow_should_show_completed?(processes) ? 'completed' : 'active'
    end

    def workflow_should_show_completed?(processes)
      processes.all? { |p| %w[skipped completed].include?(p.status) }
    end

    # index the error message without the druid so we hopefully get some overlap
    # truncate to avoid org.apache.lucene.util.BytesRefHash$MaxBytesLengthExceededException
    def index_error_message(solr_doc, process)
      return unless process.error_message

      solr_doc.error = "#{workflow_name}:#{process.name}:#{process.error_message}".truncate(MAX_ERROR_LENGTH, omission: ERROR_OMISSION)
    end
  end
end
