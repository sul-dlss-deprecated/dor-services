require 'active_fedora'

module Dor
  @@registered_classes = {}
  mattr_reader :registered_classes

  class << self
    
    def configure *args, &block
      Dor::Config.configure *args, &block
    end
    
    # Load an object and inspect its identityMetadata to figure out what class
    # to adapt it to. This is necessary when the object is not indexed, or the
    # index is missing the objectType property.
    # @param [String] pid The object's PID
    def load_instance pid
      obj = Dor::Abstract.load_instance pid
      return nil if obj.new_object?
      object_type = obj.identityMetadata.objectType.first
      object_class = registered_classes[object_type] || ActiveFedora::Base
      obj.adapt_to(object_class)
    end

    # Get objectType information from solr and load the correct class the first time, 
    # saving the overhead of using ActiveFedora::Base#adapt_to. It falls back to 
    # Dor.load_instance() if the item is not in the index, or is improperly
    # indexed.
    # @param [String] pid The object's PID
    def find pid
      resp = ActiveFedora::SolrService.instance.conn.query %{id:"#{pid}"}
      return self.load_instance pid if resp.hits.length == 0

      solr_doc = resp.hits.first
      object_type = Array(solr_doc[ActiveFedora::SolrService.solr_name('objectType',:string)]).first
      return self.load_instance pid if object_type.nil?
      
      object_class = registered_classes[object_type] || ActiveFedora::Base
      object_class.load_instance pid
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

    # datastream utilities
    'datastreams/ng_tidy',
    'datastreams/solr_doc_helper',
    'datastreams/utc_date_field_mapper',
    'datastreams/datastream_spec_solrizer',
    
    # datastreams
    'datastreams/administrative_metadata_ds',
    'datastreams/content_metadata_ds',
    'datastreams/desc_metadata_ds',
    'datastreams/embargo_metadata_ds',
    'datastreams/events_ds',
    'datastreams/identity_metadata_ds',
    'datastreams/role_metadata_ds',
    'datastreams/simple_dublin_core_ds',
    'datastreams/workflow_definition_ds',
    'datastreams/workflow_ds',

    # DOR Concerns
    'dor/identifiable',
    'dor/itemizable',
    'dor/processable',
    'dor/governable',
    'dor/describable',
    'dor/publishable',
    'dor/shelvable',
    'dor/embargoable',
    'dor/preservable',
    
    # ActiveFedora Classes
    'dor/item',
    'dor/set',
    'dor/collection',
    'dor/admin_policy_object',
    'dor/workflow_object',

    # Services
    'dor/search_service',
    'dor/metadata_service',
    'dor/registration_service',
    'dor/suri_service',
    'dor/workflow_service',
    'dor/digital_stacks_service',
    'dor/druid_utils',
    'dor/sdr_ingest_service',
    'dor/cleanup_service',
    'dor/provenance_metadata_service',
    
    # Workflow Classes
    'workflow/graph',
    'workflow/process',
    'workflow/document'
  ]
  Dependencies.each { |f| require f }
end