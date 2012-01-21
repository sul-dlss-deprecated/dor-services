require 'workflow/graph'
require 'workflow/process'

class WorkflowDefinitionDs < ActiveFedora::NokogiriDatastream 
  
  set_terminology do |t|
    t.root(:path => "workflow-def", :xmlns => '', :namespace_prefix => nil)
    t.process(:namespace_prefix => nil)
  end
  
  define_template :process do |builder,workflow,attrs|
    prereqs = attrs.delete('prerequisite')
    if prereqs.is_a?(String)
      prereqs = prereqs.split(/\s*,\s*/)
    end
    attrs.keys.each { |k| attrs[k.to_s.dasherize.to_sym] = attrs.delete(k) }
    builder.process(attrs) do |node|
      Array(prereqs).each do |prereq|
        (repo,wf,prereq_name) = prereq.split(/:/)
        if prereq_name.nil?
          prereq_name = repo
          repo = nil
        end
        if (repo == workflow.repository and wf = workflow.name)
          repo = nil
          wf = nil
        end
        attrs = (repo.nil? and wf.nil?) ? {} : { :repository => repo, :workflow => wf }
        node.prereq(attrs) { node.text prereq_name }
      end
    end
  end

  def self.xml_template
    Nokogiri::XML('<workflow-def/>')
  end
  
  def add_process(attributes)
    add_child_node(ng_xml.at_xpath('/workflow-def'), :process, self, attributes)
  end
  
  def graph(parent = nil)
    Workflow::Graph.from_processes(self.repository, self.name, self.processes, parent)
  end
  
  def processes
    ng_xml.xpath('/workflow-def/process').collect do |node|
      Workflow::Process.new(self.name, self.repository, node)
    end
  end

  def name
    ng_xml.at_xpath('/workflow-def/@id').to_s
  end
  
  def repo
    ng_xml.at_xpath('/workflow-def/@repository').to_s
  end

  def configuration
    result = ActiveSupport::OrderedHash.new
    result['repository'] = repository
    result['name'] = name
    processes.each { |process| result[process.name] = process.to_hash }
    result
  end
  
  def configuration=(hash)
    self.ng_xml = Nokogiri::XML(%{<workflow-def id="#{hash['name']}" repository="#{hash['repository']}"/>})
    i = 0
    hash.each_pair do |k,v| 
      if v.is_a?(Hash)
        add_process(v.merge({:name => k, :sequence => i+=1}))
      end
    end
    self.dirty = true
  end
  
  def to_yaml
    YAML.dump(self.configuration)
  end
  
end