# frozen_string_literal: true

module Dor
  module Workflow
    class Document
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
        Deprecation.warn(self, 'Dor::Workflow::Document is deprecated and will be removed from dor-services version 9')
        self.ng_xml = Nokogiri::XML(node)
      end

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
