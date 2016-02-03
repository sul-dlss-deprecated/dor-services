require 'active_fedora'
require 'active_support/core_ext/module/attribute_accessors'

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
      ensure_models_loaded!
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
    def find pid, opts = {}
      find_all(%{id:"#{pid}"}, opts).first || load_instance(pid)
    end

    def find_all query, opts = {}
      ensure_models_loaded!
      af_version = Gem::Version.new(ActiveFedora::VERSION)
      if opts[:lightweight] and af_version < Gem::Version.new('4.0.0.rc9')
        ActiveFedora.logger.warn("Loading of lightweight objects requires ActiveFedora >= 4.0.0")
        opts.delete(:lightweight)
      end

      resp = SearchService.query query, opts
      resp.docs.collect do |solr_doc|
        doc_version = solr_doc[INDEX_VERSION_FIELD].first rescue '0.0.0'
        doc_version = Gem::Version.new(doc_version)
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

    def ensure_models_loaded!
      [Item, Set, Collection, AdminPolicyObject, WorkflowObject]
    end

    def root
      File.dirname(__FILE__)
    end
  end

  require 'dor/version'
  require 'dor/config'
  require 'dor/exceptions'

  # patches, utilities and helpers
  require 'dor/utils/ng_tidy'
  require 'dor/utils/solr_doc_helper'
  require 'dor/utils/utc_date_field_mapper'
  require 'dor/utils/predicate_patch'

  require 'dor/datastreams/datastream_spec_solrizer'

  require 'druid-tools'

  # datastreams
  autoload :AdministrativeMetadataDS,  'dor/datastreams/administrative_metadata_ds'
  autoload :ContentMetadataDS, 'dor/datastreams/content_metadata_ds'
  autoload :DescMetadataDS,  'dor/datastreams/desc_metadata_ds'
  autoload :EmbargoMetadataDS, 'dor/datastreams/embargo_metadata_ds'
  autoload :EventsDS,  'dor/datastreams/events_ds'
  autoload :GeoMetadataDS,  'dor/datastreams/geo_metadata_ds'
  autoload :IdentityMetadataDS,  'dor/datastreams/identity_metadata_ds'
  autoload :RoleMetadataDS,  'dor/datastreams/role_metadata_ds'
  autoload :WorkflowDefinitionDs,  'dor/datastreams/workflow_definition_ds'
  autoload :WorkflowDs,  'dor/datastreams/workflow_ds'
  autoload :VersionMetadataDS,  'dor/datastreams/version_metadata_ds'
  autoload :DefaultObjectRightsDS,  'dor/datastreams/default_object_rights_ds'
  ::Object.autoload :SimpleDublinCoreDs, 'dor/datastreams/simple_dublin_core_ds'

  # DOR Concerns
  autoload :Identifiable, 'dor/models/identifiable'
  autoload :Itemizable, 'dor/models/itemizable'
  autoload :Processable, 'dor/models/processable'
  autoload :Governable, 'dor/models/governable'
  autoload :Describable, 'dor/models/describable'
  autoload :Publishable, 'dor/models/publishable'
  autoload :Shelvable, 'dor/models/shelvable'
  autoload :Embargoable, 'dor/models/embargoable'
  autoload :Preservable, 'dor/models/preservable'
  autoload :Assembleable, 'dor/models/assembleable'
  autoload :Upgradable, 'dor/models/upgradable'
  autoload :Eventable, 'dor/models/eventable'
  autoload :Versionable, 'dor/models/versionable'
  autoload :Contentable, 'dor/models/contentable'
  autoload :Editable, 'dor/models/editable'
  autoload :Discoverable, 'dor/models/discoverable'
  autoload :Geoable,      'dor/models/geoable'
  autoload :Releaseable,   'dor/models/releaseable'
  autoload :Rightsable,   'dor/models/rightsable'



  # ActiveFedora Classes
  autoload :Abstract, 'dor/models/item'
  autoload :Item, 'dor/models/item'
  autoload :Set, 'dor/models/set'
  autoload :Collection, 'dor/models/collection'
  autoload :AdminPolicyObject, 'dor/models/admin_policy_object'
  autoload :WorkflowObject, 'dor/models/workflow_object'

  # Services
  autoload :SearchService, 'dor/services/search_service'
  autoload :MetadataService, 'dor/services/metadata_service'
  autoload :RegistrationService, 'dor/services/registration_service'
  autoload :SuriService, 'dor/services/suri_service'
  autoload :WorkflowService, 'dor/services/workflow_service'
  autoload :DigitalStacksService, 'dor/services/digital_stacks_service'
  autoload :SdrIngestService, 'dor/services/sdr_ingest_service'
  autoload :CleanupService, 'dor/services/cleanup_service'
  autoload :IndexingService, 'dor/services/indexing_service'
  autoload :ProvenanceMetadataService, 'dor/services/provenance_metadata_service'
  autoload :TechnicalMetadataService, 'dor/services/technical_metadata_service'
  autoload :MergeService, 'dor/services/merge_service'
  autoload :ResetWorkspaceService, 'dor/services/reset_workspace_service'
  autoload :CleanupResetService, 'dor/services/cleanup_reset_service'

  # Versioning Classes
  module Versioning
    autoload :FileInventoryDifference, 'dor/versioning/file_inventory_difference'
  end

  # Workflow Classes
  module Workflow
    autoload :Graph, 'dor/workflow/graph'
    autoload :Process, 'dor/workflow/process'
    autoload :Document, 'dor/workflow/document'
  end
end
