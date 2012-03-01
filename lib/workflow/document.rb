module Workflow
  class Document
    include SolrDocHelper
    include OM::XML::Document
    
    set_terminology do |t|
      t.root(:path => 'workflow')
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
      wfo = Dor::WorkflowObject.find_by_name(self.workflowId.first)
      wfo ? wfo.definition : nil
    end

    def graph(parent=nil, dir=nil)
      wf_definition = self.definition
      result = wf_definition ? Workflow::Graph.from_processes(wf_definition.repo, wf_definition.name, self.processes, parent) : nil
      unless result.nil?
        result['rankdir'] = dir || 'TB'
      end
      result
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
    
    def to_solr(solr_doc=Hash.new, *args)
      wf_name = self.workflowId.first
      add_solr_value(solr_doc, 'wf', wf_name, :string, [:facetable])
      add_solr_value(solr_doc, 'wf_wps', wf_name, :string, [:facetable])
      add_solr_value(solr_doc, 'wf_wsp', wf_name, :string, [:facetable])
      process_nodes = self.find_by_terms(:workflow, :process).sort_by { |x| x['datetime'] }
      status = process_nodes.empty? ? 'empty' : (process_nodes.all? { |n| n['status'] == 'completed' } ? 'completed' : 'active')
      errors = process_nodes.select { |process| process['status'] == 'error' }.count
      add_solr_value(solr_doc, 'workflow_status', [wf_name,status,errors].join('|'), :string, [:displayable])
      
      process_nodes.each do |process|
        add_solr_value(solr_doc, 'wf_wps', "#{wf_name}:#{process['name']}", :string, [:facetable])
        add_solr_value(solr_doc, 'wf_wps', "#{wf_name}:#{process['name']}:#{process['status']}", :string, [:facetable])
        add_solr_value(solr_doc, 'wf_wsp', "#{wf_name}:#{process['status']}", :string, [:facetable])
        add_solr_value(solr_doc, 'wf_wsp', "#{wf_name}:#{process['status']}:#{process['name']}", :string, [:facetable])
        add_solr_value(solr_doc, 'wf_swp', "#{process['status']}", :string, [:facetable])
        add_solr_value(solr_doc, 'wf_swp', "#{process['status']}:#{wf_name}", :string, [:facetable])
        add_solr_value(solr_doc, 'wf_swp', "#{process['status']}:#{wf_name}:#{process['name']}", :string, [:facetable])
      end
      solr_doc['wf_wps_facet'].uniq!    if solr_doc['wf_wps_facet']
      solr_doc['wf_wsp_facet'].uniq!    if solr_doc['wf_wsp_facet']
      solr_doc['wf_swp_facet'].uniq!    if solr_doc['wf_swp_facet']
      solr_doc['workflow_status'].uniq! if solr_doc['workflow_status']
      
      solr_doc
    end
    
  end
end
