module Dor
class WorkflowDefinitionDs < ActiveFedora::OmDatastream
  include SolrDocHelper

  set_terminology do |t|
    t.root(:path => 'workflow-def', :index_as => [:not_searchable])
    t.process(:index_as => [:not_searchable])
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
        attrs = (repo.nil? && wf.nil?) ? {} : { :repository => repo, :workflow => wf }
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

  # Creates the xml used by Dor::WorkflowService#create_workflow
  # @return [String] An object's initial workflow as defined by the <workflow-def> in content
  def initial_workflow
    doc = Nokogiri::XML('<workflow/>')
    root = doc.root
    root['id'] = name
    processes.each { |proc|
      doc.create_element 'process' do |node|
        node['name'] = proc.name
        if proc.status
          node['status'] = proc.status
          node['attempts'] = '1'
        else
          node['status'] = 'waiting'
        end
        node['lifecycle'] = proc.lifecycle if proc.lifecycle
        root.add_child node
      end
    }
    Nokogiri::XML(doc.to_xml) { |x| x.noblanks }.to_xml { |config| config.no_declaration }
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
