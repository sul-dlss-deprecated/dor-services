require 'equivalent-xml'

module Dor
  module Processable
    extend ActiveSupport::Concern
    include SolrDocHelper
    include Upgradable

    included do
      has_metadata :name => 'workflows', :type => Dor::WorkflowDs, :label => 'Workflows', :control_group => 'E'
      after_initialize :set_workflows_datastream_location
    end
    
    def set_workflows_datastream_location
      if self.workflows.new?
        workflows.mimeType = 'application/xml'
        workflows.dsLocation = File.join(Dor::Config.workflow.url,"dor/objects/#{self.pid}/workflows")
      end
    end
    
    def empty_datastream?(datastream)
      if datastream.new?
        true 
      elsif datastream.class.respond_to?(:xml_template)
        datastream.content.to_s.empty? or EquivalentXml.equivalent?(datastream.content, datastream.class.xml_template)
      else
        datastream.content.to_s.empty?
      end  
    end
    
    # Self-aware datastream builders
    def build_datastream(datastream, force = false)
      ds = datastreams[datastream]
      druid = DruidTools::Druid.new(self.pid, Dor::Config.stacks.local_workspace_root)
      filename = druid.find_metadata("#{datastream}.xml")
      if not filename.nil?
        content = File.read(filename)
        ds.content = content
        ds.ng_xml = Nokogiri::XML(content) if ds.respond_to?(:ng_xml)
        ds.save unless ds.digital_object.new?
      elsif force or empty_datastream?(ds)
        proc = "build_#{datastream}_datastream".to_sym
        if respond_to? proc
          content = self.send(proc, ds)
          ds.save unless ds.digital_object.new?
        end
      end
      return ds
    end

    def cleanup()
      CleanupService.cleanup(self)
    end

    def milestones
      Dor::WorkflowService.get_milestones('dor',self.pid)
    end
    
    def to_solr(solr_doc=Hash.new, *args)
      super(solr_doc, *args)

      sortable_milestones = {}

      self.milestones.each do |milestone|
        timestamp = milestone[:at].utc.xmlschema
        sortable_milestones[milestone[:milestone]] ||= []
        sortable_milestones[milestone[:milestone]] << timestamp
        add_solr_value(solr_doc, 'lifecycle', milestone[:milestone], :string, [:searchable, :facetable])
        add_solr_value(solr_doc, 'lifecycle', "#{milestone[:milestone]}:#{timestamp}", :string, [:displayable])
        add_solr_value(solr_doc, milestone[:milestone], timestamp, :date, [:searchable, :facetable])
      end

      sortable_milestones.each do |milestone, unordered_dates|
        dates = unordered_dates.sort
        add_solr_value(solr_doc, "#{milestone}_earliest_dt", dates.first, :date, [:sortable])
        add_solr_value(solr_doc, "#{milestone}_latest_dt", dates.last, :date, [:sortable])
      end

      solr_doc
    end

    # Initilizes workflow for the object in the workflow service
    # @param [String] name of the workflow to be initialized
    # @param [String] repo name of the repository to create workflow for
    # @param [Boolean] create_ds create a 'workflows' datastream in Fedora for the object
    def initialize_workflow(name, repo='dor', create_ds=true)
      Dor::WorkflowService.create_workflow(repo, self.pid, name, Dor::WorkflowObject.initial_workflow(name), :create_ds => create_ds)
    end
  end
end
