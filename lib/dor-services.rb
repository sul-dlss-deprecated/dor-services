require 'active_fedora'
require 'active_fedora/version'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/object/blank'
require 'modsulator'
require 'dor/utils/sdr_client'

module Dor
  extend ActiveSupport::Autoload
  @@registered_classes = {}
  mattr_reader :registered_classes
  INDEX_VERSION_FIELD = 'dor_services_version_ssi'.freeze

  class << self

    def configure(*args, &block)
      Dor::Config.configure *args, &block
    end

    # Load an object and inspect its identityMetadata to figure out what class
    # to adapt it to. This is necessary when the object is not indexed, or the
    # index is missing the objectType property.
    # @param [String] pid The object's PID
    def load_instance(pid)
      Dor::Abstract.find pid, cast: true
    end

    # Get objectType information from solr and load the correct class the first time,
    # saving the overhead of using ActiveFedora::Base#adapt_to. It falls back to
    # Dor.load_instance() if the item is not in the index, or is improperly indexed.
    # @param [String] pid The object's PID
    # @return [Object] the ActiveFedora-modeled object
    def find(pid, opts = {})
      load_instance(pid)
    end

    # TODO: return enumerable and lazy load_instance
    # TODO: restrict fieldlist (fl) for non-:lightweight queries
    def find_all(query, opts = {})
      ActiveSupport::Deprecation.warn 'Dor.find_all is deprecated; use activefedora finders instead'

      resp = SearchService.query query, opts
      resp['response']['docs'].collect do |solr_doc|
        find solr_doc['id']
      end
    end

    # @deprecated
    def ensure_models_loaded!
      ActiveSupport::Deprecation.warn 'Dor.ensure_models_loaded! is unnecessary and has been deprecated.'
      eager_load!
    end

    def root
      File.dirname(__FILE__)
    end

    def logger
      require 'logger'
      @logger ||= if defined?(::Rails) && ::Rails.respond_to?(:logger)
          Rails.logger
        else
          Logger.new(STDOUT)
        end
    end
  end

  def logger
    Dor.logger
  end

  require 'dor/version'
  require 'dor/config'
  require 'dor/exceptions'

  # patches, utilities and helpers
  require 'dor/utils/ng_tidy'
  require 'dor/utils/solr_doc_helper'
  require 'dor/utils/predicate_patch'

  require 'dor/datastreams/datastream_spec_solrizer'

  require 'druid-tools'

  # datastreams
  autoload :AdministrativeMetadataDS, 'dor/datastreams/administrative_metadata_ds'
  autoload :ContentMetadataDS,        'dor/datastreams/content_metadata_ds'
  autoload :DescMetadataDS,           'dor/datastreams/desc_metadata_ds'
  autoload :EmbargoMetadataDS,        'dor/datastreams/embargo_metadata_ds'
  autoload :EventsDS,                 'dor/datastreams/events_ds'
  autoload :GeoMetadataDS,            'dor/datastreams/geo_metadata_ds'
  autoload :IdentityMetadataDS,       'dor/datastreams/identity_metadata_ds'
  autoload :RightsMetadataDS,         'dor/datastreams/rights_metadata_ds'
  autoload :RoleMetadataDS,           'dor/datastreams/role_metadata_ds'
  autoload :WorkflowDefinitionDs,     'dor/datastreams/workflow_definition_ds'
  autoload :WorkflowDs,               'dor/datastreams/workflow_ds'
  autoload :VersionMetadataDS,        'dor/datastreams/version_metadata_ds'
  autoload :DefaultObjectRightsDS,    'dor/datastreams/default_object_rights_ds'
  autoload :SimpleDublinCoreDs,       'dor/datastreams/simple_dublin_core_ds'

  # DOR Concerns
  autoload :Identifiable, 'dor/models/concerns/identifiable'
  autoload :Itemizable,   'dor/models/concerns/itemizable'
  autoload :Processable,  'dor/models/concerns/processable'
  autoload :Governable,   'dor/models/concerns/governable'
  autoload :Describable,  'dor/models/concerns/describable'
  autoload :Publishable,  'dor/models/concerns/publishable'
  autoload :Shelvable,    'dor/models/concerns/shelvable'
  autoload :Embargoable,  'dor/models/concerns/embargoable'
  autoload :Preservable,  'dor/models/concerns/preservable'
  autoload :Assembleable, 'dor/models/concerns/assembleable'
  autoload :Eventable,    'dor/models/concerns/eventable'
  autoload :Versionable,  'dor/models/concerns/versionable'
  autoload :Contentable,  'dor/models/concerns/contentable'
  autoload :Editable,     'dor/models/concerns/editable'
  autoload :Discoverable, 'dor/models/concerns/discoverable'
  autoload :Geoable,      'dor/models/concerns/geoable'
  autoload :Releaseable,  'dor/models/concerns/releaseable'
  autoload :Rightsable,   'dor/models/concerns/rightsable'

  eager_autoload do
    # ActiveFedora Classes
    autoload :Abstract,          'dor/models/abstract'
    autoload :Agreement,         'dor/models/agreement'
    autoload :Item,              'dor/models/item'
    autoload :Set,               'dor/models/set'
    autoload :Collection,        'dor/models/collection'
    autoload :AdminPolicyObject, 'dor/models/admin_policy_object'
    autoload :WorkflowObject,    'dor/models/workflow_object'
  end

  # Services
  autoload :SearchService,             'dor/services/search_service'
  autoload :IndexingService,           'dor/services/indexing_service'
  autoload :MetadataService,           'dor/services/metadata_service'
  autoload :RegistrationService,       'dor/services/registration_service'
  autoload :SuriService,               'dor/services/suri_service'
  autoload :WorkflowService,           'dor/services/workflow_service'
  autoload :DigitalStacksService,      'dor/services/digital_stacks_service'
  autoload :SdrIngestService,          'dor/services/sdr_ingest_service'
  autoload :CleanupService,            'dor/services/cleanup_service'
  autoload :ProvenanceMetadataService, 'dor/services/provenance_metadata_service'
  autoload :TechnicalMetadataService,  'dor/services/technical_metadata_service'
  autoload :MergeService,              'dor/services/merge_service'
  autoload :ResetWorkspaceService,     'dor/services/reset_workspace_service'
  autoload :CleanupResetService,       'dor/services/cleanup_reset_service'
  autoload :PublicDescMetadataService, 'dor/services/public_desc_metadata_service'

  # Workflow Classes
  module Workflow
    autoload :Graph,    'dor/workflow/graph'
    autoload :Process,  'dor/workflow/process'
    autoload :Document, 'dor/workflow/document'
  end

  eager_load!
end
