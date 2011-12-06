class WorkflowDs < ActiveFedora::NokogiriDatastream 
  
  set_terminology do |t|
    t.root(:path=>"workflow", :xmlns => '', :namespace_prefix => nil)
    t.workflowId(:path=>{:attribute => "id"}, :index_as => [:displayable, :facetable])
    t.process(:path=>'process', :namespace_prefix => nil) {
      t._name(:path=>{:attribute=>"name"}, :index_as => [:displayable, :facetable, :sortable])
      t.status(:path=>{:attribute=>"status"}, :index_as => [:displayable, :facetable, :sortable])
      t.timestamp(:path=>{:attribute=>"datetime"}, :index_as => [:searchable, :sortable])
      t.elapsed(:path=>{:attribute=>"elapsed"})
      t.lifecycle(:path=>{:attribute=>"lifecycle"}, :index_as => [:displayable, :facetable, :sortable])
      t.attempts(:path=>{:attribute=>"attempts"})
    }
  end

  def definition
    wfo = Dor::WorkflowObject.find_by_name(self.workflowId.first)
    wfo ? wfo.definition : nil
  end
  
  def graph(parent = nil)
    wf_definition = self.definition
    wf_definition ? Workflow::Graph.from_processes(wf_definition.repository, wf_definition.name, self.processes, parent) : nil
  end
  
  def processes
    if self.definition
      self.definition.processes.collect do |process|
        node = ng_xml.at("/workflow/process[@name = '#{process.name}']")
        process.update!(node) unless node.nil?
        process
      end
    else
      []
    end
  end
    
end