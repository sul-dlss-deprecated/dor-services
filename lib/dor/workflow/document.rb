module Dor
module Workflow
  class Document
    include SolrDocHelper
    include ::OM::XML::Document

    set_terminology do |t|
      t.root(:path => 'workflow')
      t.repository(:path => {:attribute => 'repository'})
      t.workflowId(:path => {:attribute => 'id'})
      t.process do
        t.name_(:path => {:attribute => 'name'})
        t.status(:path => {:attribute => 'status'})
        t.timestamp(:path => {:attribute => 'datetime'}) # , :data_type => :date)
        t.elapsed(:path => {:attribute => 'elapsed'})
        t.lifecycle(:path => {:attribute => 'lifecycle'})
        t.attempts(:path => {:attribute => 'attempts'}, :index_as => [:not_searchable])
        t.version(:path => {:attribute => 'version'})
      end
    end

    @@definitions = {}

    def initialize(node)
      self.ng_xml = Nokogiri::XML(node)
    end

    # is this an incomplete workflow with steps that have a priority > 0
    def expedited?
      processes.any? { |proc| !proc.completed? && proc.priority.to_i > 0 }
    end

    # @return [Integer] value of the first > 0 priority.  Defaults to 0
    def priority
      processes.map {|proc| proc.priority.to_i }.detect(0) {|p| p > 0}
    end

    # @return [Boolean] if any process node does not have version, returns true, false otherwise (all processes have version)
    def active?
      ng_xml.at_xpath('/workflow/process[not(@version)]') ? true : false
    end

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

    def graph(parent = nil, dir = nil)
      wf_definition = definition
      result = wf_definition ? Workflow::Graph.from_processes(wf_definition.repo, wf_definition.name, processes, parent) : nil
      result['rankdir'] = dir || 'TB' unless result.nil?
      result
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
          node = ng_xml.at("/workflow/process[@name = '#{process.name}']")
          process.update!(node, self) unless node.nil?
          process
        end
      else
        find_by_terms(:workflow, :process).collect do |x|
          pnode = Dor::Workflow::Process.new(repository, workflowId, {})
          pnode.update!(x, self)
          pnode
        end.sort_by(&:datetime)
      end
    end

    def workflow_should_show_completed?(processes)
      processes.all? {|p| ['skipped', 'completed', '', nil].include?(p.status)}
    end

    def to_solr(solr_doc = {}, *args)
      wf_name = workflowId.first
      repo = repository.first
      wf_solr_type = :string
      wf_solr_attrs = [:symbol]
      add_solr_value(solr_doc, 'wf',     wf_name, wf_solr_type, wf_solr_attrs)
      add_solr_value(solr_doc, 'wf_wps', wf_name, wf_solr_type, wf_solr_attrs)
      add_solr_value(solr_doc, 'wf_wsp', wf_name, wf_solr_type, wf_solr_attrs)
      status = processes.empty? ? 'empty' : (workflow_should_show_completed?(processes) ? 'completed' : 'active')
      errors = processes.count(&:error?)
      add_solr_value(solr_doc, 'workflow_status', [wf_name, status, errors, repo].join('|'), wf_solr_type, wf_solr_attrs)

      processes.each do |process|
        next unless process.status.present?
        # add a record of the robot having operated on this item, so we can track robot activity
        if !process.date_time.blank? && process.status && (process.status == 'completed' || process.status == 'error')
          solr_doc["wf_#{wf_name}_#{process.name}_dttsi"] = Time.parse(process.date_time).utc.iso8601
        end
        # index the error message without the druid so we hopefully get some overlap
        add_solr_value(solr_doc, 'wf_error', "#{wf_name}:#{process.name}:#{process.error_message}", wf_solr_type, wf_solr_attrs) if process.error_message
        add_solr_value(solr_doc, 'wf_wsp', "#{wf_name}:#{process.status}", wf_solr_type, wf_solr_attrs)
        add_solr_value(solr_doc, 'wf_wsp', "#{wf_name}:#{process.status}:#{process.name}", wf_solr_type, wf_solr_attrs)
        add_solr_value(solr_doc, 'wf_wps', "#{wf_name}:#{process.name}", wf_solr_type, wf_solr_attrs)
        add_solr_value(solr_doc, 'wf_wps', "#{wf_name}:#{process.name}:#{process.status}", wf_solr_type, wf_solr_attrs)
        add_solr_value(solr_doc, 'wf_swp', "#{process.status}", wf_solr_type, wf_solr_attrs)
        add_solr_value(solr_doc, 'wf_swp', "#{process.status}:#{wf_name}", wf_solr_type, wf_solr_attrs)
        add_solr_value(solr_doc, 'wf_swp', "#{process.status}:#{wf_name}:#{process.name}", wf_solr_type, wf_solr_attrs)
        next unless process.state != process.status
        add_solr_value(solr_doc, 'wf_wsp', "#{wf_name}:#{process.state}:#{process.name}", wf_solr_type, wf_solr_attrs)
        add_solr_value(solr_doc, 'wf_wps', "#{wf_name}:#{process.name}:#{process.state}", wf_solr_type, wf_solr_attrs)
        add_solr_value(solr_doc, 'wf_swp', "#{process.state}", wf_solr_type, wf_solr_attrs)
        add_solr_value(solr_doc, 'wf_swp', "#{process.state}:#{wf_name}", wf_solr_type, wf_solr_attrs)
        add_solr_value(solr_doc, 'wf_swp', "#{process.state}:#{wf_name}:#{process.name}", wf_solr_type, wf_solr_attrs)
      end

      solr_doc[Solrizer.solr_name('wf_wps', :symbol)].uniq! if solr_doc[Solrizer.solr_name('wf_wps', :symbol)]
      solr_doc[Solrizer.solr_name('wf_wsp', :symbol)].uniq! if solr_doc[Solrizer.solr_name('wf_wsp', :symbol)]
      solr_doc[Solrizer.solr_name('wf_swp', :symbol)].uniq! if solr_doc[Solrizer.solr_name('wf_swp', :symbol)]
      solr_doc['workflow_status'].uniq! if solr_doc['workflow_status']

      solr_doc
    end

    def inspect
      "#<#{self.class.name}:#{object_id}>"
    end
  end
end
end
