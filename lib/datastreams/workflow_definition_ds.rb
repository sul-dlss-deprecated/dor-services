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
  
  def prerequisites
    @node.xpath('prereq').collect do |p| 
      if (p['repository'].nil? and p['workflow'].nil?) or (p['repository'] == workflow.repository and p['workflow'] == workflow.name)
        p.text.to_s
      else
        [(p['repository'] or workflow.repository),(p['workflow'] or workflow.name),p.text.to_s].join(':')
      end
    end
  end
  
end

class WorkflowDefinitionDs < ActiveFedora::NokogiriDatastream 
  
  define_template :process do |builder,workflow,name,seq,label,lifecycle,prereqs|
    attrs = {:name => name}
    attrs[:sequence] = seq unless seq.nil?
    attrs[:lifecycle] = lifecycle unless lifecycle.nil?
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

  def add_process(name, seq, label, lifecycle, prereqs)
    add_child_node(ng_xml.at_xpath('/workflow'), :process, self, name, seq, label, lifecycle, prereqs)
  end
  
  def processes
    ng_xml.xpath('/workflow/process').collect do |node|
      WorkflowProcess.new(self, node)
    end
  end

  def name
    ng_xml.at_xpath('/workflow/@id').to_s
  end
  
  def repository
    ng_xml.at_xpath('/workflow/@repository').to_s
  end
  
  def configuration
    result = {
      'repository' => repository,
      'name' => name
    }
    processes.each_pair do |process_name,process|
      result[process_name] = {
        'prerequisites' => process.prerequisites.collect { |p| p.name }
      }
    end
  end
  
  def configuration=(hash)
    ng_xml = Nokogiri::XML(%{<workflow id="#{hash['name']}" repository="#{hash['repository']}"/>})
    i = 0
    hash.each_pair do |k,v| 
      if v.is_a?(Hash)
        add_process(k,i+=1,nil,nil,v['prerequisite'])
      end
    end
  end
  
  def to_yaml
    s = StringIO.new('')
    YAML.dump(self.configuration, s)
    s.string
  end
  
end