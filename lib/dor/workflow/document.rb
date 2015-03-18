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
        t.version(:path=>{:attribute=>"version"})
      }
    end
    @@definitions={}
    def initialize node
      self.ng_xml = Nokogiri::XML(node)
    end
    #is this an incomplete workflow with steps that have a priority > 0
    def expedited?
      processes.any? { |proc| !proc.completed? && proc.priority.to_i > 0 }
    end

    # @return [Integer] value of the first > 0 priority.  Defaults to 0
    def priority
      processes.map {|proc| proc.priority.to_i }.detect(0) {|p| p > 0}
    end

    # @return [Boolean] if any process node does not have version, returns true, false otherwise (all processes have version)
    def active?
      ng_xml.at_xpath("/workflow/process[not(@version)]") ? true : false
    end

    def definition
      @definition ||= begin
        if @@definitions.has_key? self.workflowId.first
          @@definitions[self.workflowId.first]
        else
        wfo = Dor::WorkflowObject.find_by_name(self.workflowId.first)
        wf_def=wfo ? wfo.definition : nil
        @@definitions[self.workflowId.first] = wf_def
        wf_def
        end
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
      @processes ||=
      if self.definition
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

    def workflow_should_show_completed? processes
      return processes.all?{|p| ['skipped', 'completed', '', nil].include?(p.status)}
    end

    def to_solr(solr_doc=Hash.new, *args)
      wf_name = self.workflowId.first
      repo = self.repository.first
      add_solr_value(solr_doc, 'wf', wf_name, :string, [:facetable])
      add_solr_value(solr_doc, 'wf_wps', wf_name, :string, [:facetable])
      add_solr_value(solr_doc, 'wf_wsp', wf_name, :string, [:facetable])
      status = processes.empty? ? 'empty' : (workflow_should_show_completed?(processes) ? 'completed' : 'active')
      errors = processes.select(&:error?).count
      add_solr_value(solr_doc, 'workflow_status', [wf_name,status,errors,repo].join('|'), :string, [:displayable])

      processes.each do |process|
        if process.status.present?
          #add a record of the robot having operated on this item, so we can track robot activity
          if process.date_time and process.status and (process.status == 'completed' || process.status == 'error')
            add_solr_value(solr_doc, "wf_#{wf_name}_#{process.name}", process.date_time+'Z', :date)
          end
          add_solr_value(solr_doc, 'wf_error', "#{wf_name}:#{process.name}:#{process.error_message}", :string, [:facetable,:displayable]) if process.error_message #index the error message without the druid so we hopefully get some overlap
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