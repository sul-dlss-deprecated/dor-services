module Dor
module Workflow
  class Document
    include SolrDocHelper
    include OM::XML::Document
    
    set_terminology do |t|
      t.root(:path => 'workflow')
      t.repository(:path=>{:attribute => "repository"})
      t.workflowId(:path=>{:attribute => "id"})
      t.process {
        t.name_(:path=>{:attribute=>"name"})
        t.status(:path=>{:attribute=>"status"})
        t.timestamp(:path=>{:attribute=>"datetime"})#, :data_type => :date)
        t.elapsed(:path=>{:attribute=>"elapsed"})
        t.lifecycle(:path=>{:attribute=>"lifecycle"})
        t.attempts(:path=>{:attribute=>"attempts"}, :index_as => [:not_searchable])
      }
    end
    
    def initialize node
      self.ng_xml = Nokogiri::XML(node)
    end
    
    def definition
      @definition ||= begin
        wfo = Dor::WorkflowObject.find_by_name(self.workflowId.first)
        wfo ? wfo.definition : nil
      end
    end

    def graph(parent=nil, dir=nil)
      wf_definition = self.definition
      result = wf_definition ? Workflow::Graph.from_processes(wf_definition.repo, wf_definition.name, self.processes, parent) : nil
      unless result.nil?
        result['rankdir'] = dir || 'TB'
      end
      result
    end

    def [](value)
      self.processes.find { |p| p.name == value }
    end
    
    def processes
      #if the workflow service didnt return any processes, dont return any processes from the reified wf
      if ng_xml.search("/workflow/process").length == 0
        return []
      end
      @processes ||= if self.definition
        self.definition.processes.collect do |process|
          node = ng_xml.at("/workflow/process[@name = '#{process.name}']")
          process.update!(node,self) unless node.nil?
          process
        end
      else
        self.find_by_terms(:workflow, :process).collect do |x| 
          pnode = Dor::Workflow::Process.new(self.repository, self.workflowId, {})
          pnode.update!(x,self)
          pnode
        end.sort_by(&:datetime)
      end
    end

    def to_solr(solr_doc=Hash.new, *args)
      wf_name = self.workflowId.first
      repo=self.repository.first
      add_solr_value(solr_doc, 'wf', wf_name, :string, [:facetable])
      add_solr_value(solr_doc, 'wf_wps', wf_name, :string, [:facetable])
      add_solr_value(solr_doc, 'wf_wsp', wf_name, :string, [:facetable])
      status = processes.empty? ? 'empty' : (processes.all?(&:completed?) ? 'completed' : 'active')
      errors = processes.select(&:error?).count
      add_solr_value(solr_doc, 'workflow_status', [wf_name,status,errors,repo].join('|'), :string, [:displayable])
      
      processes.each do |process|
        if process.status.present?
          
          add_solr_value(solr_doc, 'wf_error', "#{wf_name}:#{process.name}:#{process.error_message}") if process.error_message #index the error message without the druid so we hopefully get some overlap
          add_solr_value(solr_doc, 'wf_wsp', "#{wf_name}:#{process.status}", :string, [:facetable])
          add_solr_value(solr_doc, 'wf_wsp', "#{wf_name}:#{process.status}:#{process.name}", :string, [:facetable])
          add_solr_value(solr_doc, 'wf_wps', "#{wf_name}:#{process.name}", :string, [:facetable])
          add_solr_value(solr_doc, 'wf_wps', "#{wf_name}:#{process.name}:#{process.status}", :string, [:facetable])
          add_solr_value(solr_doc, 'wf_swp', "#{process.status}", :string, [:facetable])
          add_solr_value(solr_doc, 'wf_swp', "#{process.status}:#{wf_name}", :string, [:facetable])
          add_solr_value(solr_doc, 'wf_swp', "#{process.status}:#{wf_name}:#{process.name}", :string, [:facetable])
          if process.state != process.status
            add_solr_value(solr_doc, 'wf_wsp', "#{wf_name}:#{process.state}:#{process.name}", :string, [:facetable])
            add_solr_value(solr_doc, 'wf_wps', "#{wf_name}:#{process.name}:#{process.state}", :string, [:facetable])
            add_solr_value(solr_doc, 'wf_swp', "#{process.state}", :string, [:facetable])
            add_solr_value(solr_doc, 'wf_swp', "#{process.state}:#{wf_name}", :string, [:facetable])
            add_solr_value(solr_doc, 'wf_swp', "#{process.state}:#{wf_name}:#{process.name}", :string, [:facetable])
          end
        end
      end
      
      solr_doc['wf_wps_facet'].uniq!    if solr_doc['wf_wps_facet']
      solr_doc['wf_wsp_facet'].uniq!    if solr_doc['wf_wsp_facet']
      solr_doc['wf_swp_facet'].uniq!    if solr_doc['wf_swp_facet']
      solr_doc['workflow_status'].uniq! if solr_doc['workflow_status']
      
      solr_doc
    end
    
    def inspect
      "#<#{self.class.name}:#{self.object_id}>"
    end
  end
end
end