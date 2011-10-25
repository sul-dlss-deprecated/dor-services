require 'workflow/graph'

class WorkflowProcess

  def initialize(workflow, node)
    @workflow = workflow
    @node = node
  end
  
  def name
    @node['name']
  end
  
  def sequence
    @node['sequence']
  end
  
  def lifecycle
    @node['lifecycle']
  end
  
  def label
    @node.at_xpath('label/text()').to_s
  end
  
  def batch_limit
    @node['batch-limit'].to_i
  end
  
  def error_limit
    @node['error-limit'].to_i
  end
  
  def prerequisites
    @node.xpath('prereq').collect do |p| 
      if (p['repository'].nil? and p['workflow'].nil?) or (p['repository'] == @workflow.repository and p['workflow'] == @workflow.name)
        p.text.to_s
      else
        [(p['repository'] or @workflow.repository),(p['workflow'] or @workflow.name),p.text.to_s].join(':')
      end
    end
  end
  
  def to_hash
    {
      'batch_limit' => self.batch_limit,
      'error_limit' => self.error_limit,
      'prerequisite' => self.prerequisites
    }.reject { |k,v| v.nil? or v == 0 or (v.respond_to?(:empty?) and v.empty?) }
  end
  
end

class WorkflowDefinitionDs < ActiveFedora::NokogiriDatastream 
  
  define_template :process do |builder,workflow,attrs|
    prereqs = attrs.delete('prerequisite')
    if prereqs.is_a?(String)
      prereqs = prereqs.split(/\s*,\s*/)
    end
    attrs.keys.each { |k| attrs[k.to_s.dasherize.to_sym] = attrs.delete(k) }
    builder.process(attrs) do |node|
      prereqs.each do |prereq|
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

  def add_process(attributes)
    add_child_node(ng_xml.at_xpath('/workflow-def'), :process, self, attributes)
  end
  
  def graph(parent = nil)
    Workflow::Graph.from_config(self.name, self.configuration, parent)
  end
  
  def processes
    ng_xml.xpath('/workflow-def/process').collect do |node|
      WorkflowProcess.new(self, node)
    end
  end

  def name
    ng_xml.at_xpath('/workflow-def/@id').to_s
  end
  
  def repository
    ng_xml.at_xpath('/workflow-def/@repository').to_s
  end

  def configuration
    result = {
      'repository' => repository,
      'name' => name
    }
    processes.each { |process| result[process.name] = process.to_hash }
    result
  end
  
  def configuration=(hash)
    self.ng_xml = Nokogiri::XML(%{<workflow id="#{hash['name']}" repository="#{hash['repository']}"/>})
    i = 0
    hash.each_pair do |k,v| 
      if v.is_a?(Hash)
        add_process(v.merge({:name => k, :sequence => i+=1}))
      end
    end
  end
  
  def to_yaml
    YAML.dump(self.configuration)
  end
  
end