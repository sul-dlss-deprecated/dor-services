# frozen_string_literal: true

module Dor
  # @deprecated
  class WorkflowDefinitionDs < ActiveFedora::OmDatastream
    include SolrDocHelper

    set_terminology do |t|
      t.root(path: 'workflow-def', index_as: [:not_searchable])
      t.process(index_as: [:not_searchable])
    end

    define_template :process do |builder, workflow, attrs|
      prereqs = attrs.delete('prerequisite')
      prereqs = prereqs.split(/\s*,\s*/) if prereqs.is_a?(String)
      attrs.keys.each { |k| attrs[k.to_s.dasherize.to_sym] = attrs.delete(k) }
      builder.process(attrs) do |node|
        Array(prereqs).each do |prereq|
          (repo, wf, prereq_name) = prereq.split(/:/)
          if prereq_name.nil?
            prereq_name = repo
            repo = nil
          end
          if repo == workflow.repo && wf = workflow.name
            repo = nil
            wf = nil
          end
          attrs = repo.nil? && wf.nil? ? {} : { repository: repo, workflow: wf }
          node.prereq(attrs) { node.text prereq_name }
        end
      end
    end

    def self.xml_template
      Nokogiri::XML('<workflow-def/>')
    end

    def add_process(attributes)
      ng_xml_will_change!
      add_child_node(ng_xml.at_xpath('/workflow-def'), :process, self, attributes)
    end

    def processes
      ng_xml.xpath('/workflow-def/process').collect do |node|
        Workflow::Process.new(repo, name, node)
      end.sort { |a, b| (a.sequence || 0) <=> (b.sequence || 0) }
    end

    def name
      ng_xml.at_xpath('/workflow-def/@id').to_s
    end

    def repo
      ng_xml.at_xpath('/workflow-def/@repository').to_s
    end

    def to_solr(solr_doc = {}, *args)
      solr_doc = super(solr_doc, *args)
      add_solr_value(solr_doc, 'workflow_name', name, :symbol, [:symbol])
      processes.each do |p|
        add_solr_value(solr_doc, 'process', "#{p.name}|#{p.label}", :symbol, [:displayable])
      end
      solr_doc
    end

    # maintain AF < 8 indexing behavior
    def prefix
      ''
    end
  end
end
