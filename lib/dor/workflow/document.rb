# frozen_string_literal: true

module Dor
  module Workflow
    class Document
      extend Deprecation
      include SolrDocHelper
      include ::OM::XML::Document

      ERROR_OMISSION = '... (continued)'
      private_constant :ERROR_OMISSION

      # see https://lucene.apache.org/core/7_3_1/core/org/apache/lucene/util/BytesRefHash.MaxBytesLengthExceededException.html
      MAX_ERROR_LENGTH = 32_768 - 2 - ERROR_OMISSION.length
      private_constant :MAX_ERROR_LENGTH

      WF_SOLR_TYPE = :string
      private_constant :WF_SOLR_TYPE
      WF_SOLR_ATTRS = [:symbol].freeze
      private_constant :WF_SOLR_ATTRS

      set_terminology do |t|
        t.root(path: 'workflow')
        t.repository(path: { attribute: 'repository' })
        t.workflowId(path: { attribute: 'id' })
        t.process do
          t.name_(path: { attribute: 'name' })
          t.status(path: { attribute: 'status' })
          t.timestamp(path: { attribute: 'datetime' }) # , :data_type => :date)
          t.elapsed(path: { attribute: 'elapsed' })
          t.lifecycle(path: { attribute: 'lifecycle' })
          t.attempts(path: { attribute: 'attempts' }, index_as: [:not_searchable])
          t.version(path: { attribute: 'version' })
        end
      end

      @@definitions = {}

      def initialize(node)
        self.ng_xml = Nokogiri::XML(node)
      end

      # is this an incomplete workflow with steps that have a priority > 0
      def expedited?
        processes.any? { |proc| !proc.completed? && proc.priority.to_i > 0 }
      end

      # @return [Integer] value of the first > 0 priority.  Defaults to 0
      def priority
        processes.map { |proc| proc.priority.to_i }.detect(0) { |p| p > 0 }
      end

      # @return [Boolean] if any process node does not have version, returns true, false otherwise (all processes have version)
      def active?
        ng_xml.at_xpath('/workflow/process[not(@version)]') ? true : false
      end
      deprecation_deprecate active?: 'Workflow::Document#active? has moved to Argo. This implementation does not work with the new workflow server, which returns all versions'

      # @return [Dor::WorkflowDefinitionDs]
      def definition
        @definition ||= begin
          if @@definitions.key? workflowId.first
            @@definitions[workflowId.first]
          else
            wfo = Dor::WorkflowObject.find_by_name(workflowId.first)
            wf_def = wfo ? wfo.definition : nil
            @@definitions[workflowId.first] = wf_def
            wf_def
          end
        end
      end

      def [](value)
        processes.find { |p| p.name == value }
      end

      def processes
        # if the workflow service didnt return any processes, dont return any processes from the reified wf
        return [] if ng_xml.search('/workflow/process').length == 0

        @processes ||=
          if definition
            definition.processes.collect do |process|
              nodes = ng_xml.xpath("/workflow/process[@name = '#{process.name}']")
              node = nodes.max { |a, b| a.attr('version').to_i <=> b.attr('version').to_i }
              process.update!(node, self)
            end
          else
            find_by_terms(:workflow, :process).collect do |x|
              pnode = Dor::Workflow::Process.new(repository, workflowId, {})
              pnode.update!(x, self)
            end.sort_by(&:datetime)
          end
      end

      def workflow_should_show_completed?(processes)
        processes.all? { |p| ['skipped', 'completed', '', nil].include?(p.status) }
      end

      def to_solr(solr_doc = {}, *_args)
        wf_name = workflowId.first
        repo = repository.first

        add_solr_value(solr_doc, 'wf',     wf_name, WF_SOLR_TYPE, WF_SOLR_ATTRS)
        add_solr_value(solr_doc, 'wf_wps', wf_name, WF_SOLR_TYPE, WF_SOLR_ATTRS)
        add_solr_value(solr_doc, 'wf_wsp', wf_name, WF_SOLR_TYPE, WF_SOLR_ATTRS)
        status = processes.empty? ? 'empty' : (workflow_should_show_completed?(processes) ? 'completed' : 'active')
        errors = processes.count(&:error?)
        add_solr_value(solr_doc, 'workflow_status', [wf_name, status, errors, repo].join('|'), WF_SOLR_TYPE, WF_SOLR_ATTRS)

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

        solr_doc[Solrizer.solr_name('wf_wps', :symbol)]&.uniq!
        solr_doc[Solrizer.solr_name('wf_wsp', :symbol)]&.uniq!
        solr_doc[Solrizer.solr_name('wf_swp', :symbol)]&.uniq!
        solr_doc['workflow_status']&.uniq!

        solr_doc
      end

      def inspect
        "#<#{self.class.name}:#{object_id}>"
      end

      private

      # index the error message without the druid so we hopefully get some overlap
      # truncate to avoid org.apache.lucene.util.BytesRefHash$MaxBytesLengthExceededException
      def index_error_message(solr_doc, wf_name, process)
        return unless process.error_message

        error_message = "#{wf_name}:#{process.name}:#{process.error_message}".truncate(MAX_ERROR_LENGTH, omission: ERROR_OMISSION)
        add_solr_value(solr_doc, 'wf_error', error_message, WF_SOLR_TYPE, WF_SOLR_ATTRS)
      end
    end
  end
end
