require 'active_fedora'

module Dor
  @@registered_classes = {}
  mattr_reader :registered_classes
  INDEX_VERSION_FIELD = 'dor_services_version_facet'

  class << self
    
    def configure *args, &block
      Dor::Config.configure *args, &block
    end
    
    # Load an object and inspect its identityMetadata to figure out what class
    # to adapt it to. This is necessary when the object is not indexed, or the
    # index is missing the objectType property.
    # @param [String] pid The object's PID
    def load_instance pid
      obj = Dor::Abstract.find pid
      return nil if obj.new_object?
      object_type = obj.identityMetadata.objectType.first
      object_class = registered_classes[object_type] || Dor::Item
      obj.adapt_to(object_class)
    end

    # Get objectType information from solr and load the correct class the first time, 
    # saving the overhead of using ActiveFedora::Base#adapt_to. It falls back to 
    # Dor.load_instance() if the item is not in the index, or is improperly
    # indexed.
    # @param [String] pid The object's PID
    def find pid, opts={}
      self.find_all(%{id:"#{pid}"}, opts).first || self.load_instance(pid)
    end
    
    def find_all query, opts={}
      af_version = Gem::Version.new(ActiveFedora::VERSION)
      if opts[:lightweight] and af_version < Gem::Version.new('4.0.0.rc9')
        ActiveFedora.logger.warn("Loading of lightweight objects requires ActiveFedora >= 4.0.0")
        opts.delete(:lightweight)
      end
      
      resp = SearchService.query query, opts
      resp.docs.collect do |solr_doc|
        doc_version = Gem::Version.new(solr_doc[INDEX_VERSION_FIELD].first)
        object_type = Array(solr_doc[ActiveFedora::SolrService.solr_name('objectType',:string)]).first
        object_class = registered_classes[object_type] || ActiveFedora::Base
        if opts[:lightweight] and doc_version >= Gem::Version.new('3.1.0')
          begin
            object_class.load_instance_from_solr solr_doc['id'], solr_doc
          rescue Exception => e
            ActiveFedora.logger.warn("Exception: '#{e.message}' trying to load #{solr_doc['id']} from solr. Loading from Fedora")
            load_instance(solr_doc['id'])
          end
        else
          load_instance solr_doc['id']
        end
      end
    end

    # Reload the entire dor-services gem, preserving configuration info
    def reload!
      configuration = Dor::Config.to_hash
      temp_v = $-v
      $-v = nil
      begin
        Dependencies.each { |f| load File.join(File.dirname(__FILE__), "#{f}.rb") }
      ensure
        $-v = temp_v
      end
      Dor::Config.configure { |config| config.deep_merge!(configuration) }
      Dor
    end
    
  end
  
  Dependencies = [
    'dor/version',
    'dor/config',
    'dor/exceptions',

    # patches, utilities and helpers
    'dor/utils/druid_utils',
    'dor/utils/ng_tidy',
    'dor/utils/solr_doc_helper',
    'dor/utils/utc_date_field_mapper',
    
    # datastreams
    'dor/datastreams/administrative_metadata_ds',
    'dor/datastreams/content_metadata_ds',
    'dor/datastreams/desc_metadata_ds',
    'dor/datastreams/embargo_metadata_ds',
    'dor/datastreams/events_ds',
    'dor/datastreams/identity_metadata_ds',
    'dor/datastreams/role_metadata_ds',
    'dor/datastreams/simple_dublin_core_ds',
    'dor/datastreams/workflow_definition_ds',
    'dor/datastreams/workflow_ds',
    'dor/datastreams/datastream_spec_solrizer',

    # DOR Concerns
    'dor/models/identifiable',
    'dor/models/itemizable',
    'dor/models/processable',
    'dor/models/governable',
    'dor/models/describable',
    'dor/models/publishable',
    'dor/models/shelvable',
    'dor/models/embargoable',
    'dor/models/preservable',
    'dor/models/assembleable',
    
    # ActiveFedora Classes
    'dor/models/item',
    'dor/models/set',
    'dor/models/collection',
    'dor/models/admin_policy_object',
    'dor/models/workflow_object',

    # Services
    'dor/services/search_service',
    'dor/services/metadata_service',
    'dor/services/registration_service',
    'dor/services/suri_service',
    'dor/services/workflow_service',
    'dor/services/digital_stacks_service',
    'dor/services/sdr_ingest_service',
    'dor/services/cleanup_service',
    'dor/services/provenance_metadata_service',
    
    # Workflow Classes
    'dor/workflow/graph',
    'dor/workflow/process',
    'dor/workflow/document'
  ]
  Dependencies.each { |f| require f }
end