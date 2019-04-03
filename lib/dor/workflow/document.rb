# frozen_string_literal: true

module Dor
  module Workflow
    class Document
      extend Deprecation
      include ::OM::XML::Document

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

      def inspect
        "#<#{self.class.name}:#{object_id}>"
      end
    end
  end
end
