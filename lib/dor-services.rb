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
    def find pid, opts={}
      self.find_all(%{id:"#{pid}"}, opts).first || self.load_instance(pid)
    end
    
    def find_all query, opts={}
      resp = ActiveFedora::SolrService.instance.conn.query query
      resp.hits.collect do |solr_doc|
        object_type = Array(solr_doc[ActiveFedora::SolrService.solr_name('objectType',:string)]).first
        object_class = registered_classes[object_type] || ActiveFedora::Base
        if opts[:lightweight]
          object_class.load_instance_from_solr solr_doc['id'], solr_doc
        else
          object_class.load_instance solr_doc['id']
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