module Dor
  module Processable
    extend ActiveSupport::Concern
    include SolrDocHelper

    included do
      has_metadata :name => 'workflows', :type => WorkflowDs, :label => 'Workflows'
      self.ds_specs.instance_eval do
        class << self
          alias_method :_retrieve, :[]
          def [](key)
            self._retrieve(key) || (key =~ /WF$/ ? { :type => WorkflowDs } : nil)
          end
        end
      end
    end
    
    def initialize *args
      super *args
      self.workflows.set_datastream_location
    end
    
    # Self-aware datastream builders
    def build_datastream(datastream, force = false)
      ds = datastreams[datastream]
      if force or ds.new_object? or (ds.content.to_s.empty?)
        proc = "build_#{datastream}_datastream".to_sym
        if respond_to? proc
          content = self.send(proc, ds)
          ds.save
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
      self.milestones.each do |milestone|
        timestamp = milestone[:at].utc.xmlschema
        add_solr_value(solr_doc, 'lifecycle', "#{milestone[:milestone]}:#{timestamp}", :string, [:searchable, :facetable])
        add_solr_value(solr_doc, milestone[:milestone], timestamp, :date, [:searchable, :facetable, :sortable])
      end
      solr_doc
    end
  end
end
