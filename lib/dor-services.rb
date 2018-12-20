# frozen_string_literal: true

require 'active_fedora'
require 'active_fedora/version'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/object/blank'
require 'dor/utils/sdr_client'

module Dor
  extend ActiveSupport::Autoload
  @@registered_classes = {}
  mattr_reader :registered_classes
  INDEX_VERSION_FIELD = 'dor_services_version_ssi'

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
    def find(pid, _opts = {})
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

  autoload_under 'indexers' do
    autoload :CompositeIndexer
    autoload :DataIndexer
    autoload :DescribableIndexer
    autoload :EditableIndexer
    autoload :IdentifiableIndexer
    autoload :ProcessableIndexer
    autoload :ReleasableIndexer
  end

  # datastreams
  autoload_under 'datastreams' do
    autoload :AdministrativeMetadataDS
    autoload :ContentMetadataDS
    autoload :DefaultObjectRightsDS
    autoload :DescMetadataDS
    autoload :EmbargoMetadataDS
    autoload :EventsDS
    autoload :GeoMetadataDS
    autoload :IdentityMetadataDS
    autoload :ProvenanceMetadataDS
    autoload :RightsMetadataDS
    autoload :RoleMetadataDS
    autoload :SimpleDublinCoreDs
    autoload :TechnicalMetadataDS
    autoload :VersionMetadataDS
    autoload :WorkflowDefinitionDs
    autoload :WorkflowDs
  end

  # DOR Concerns
  autoload_under 'models/concerns' do
    autoload :Identifiable
    autoload :Itemizable
    autoload :Processable
    autoload :Governable
    autoload :Describable
    autoload :Publishable
    autoload :Shelvable
    autoload :Embargoable
    autoload :Preservable
    autoload :Assembleable
    autoload :Eventable
    autoload :Versionable
    autoload :Contentable
    autoload :Editable
    autoload :Discoverable
    autoload :Geoable
    autoload :Releaseable
    autoload :Rightsable
  end

  eager_autoload do
    # ActiveFedora Classes
    autoload_under 'models' do
      autoload :Abstract
      autoload :Agreement
      autoload :Item
      autoload :Set
      autoload :Collection
      autoload :AdminPolicyObject
      autoload :WorkflowObject
    end
  end

  # Services
  autoload_under 'services' do
    autoload :SearchService
    autoload :ShelvingService
    autoload :IndexingService
    autoload :MetadataService
    autoload :RegistrationService
    autoload :SuriService
    autoload :WorkflowService
    autoload :DatastreamBuilder
    autoload :DigitalStacksService
    autoload :SdrIngestService
    autoload :CleanupService
    autoload :ProvenanceMetadataService
    autoload :TechnicalMetadataService
    autoload :FileMetadataMergeService
    autoload :SecondaryFileNameService
    autoload :MergeService
    autoload :ReleaseTagService
    autoload :ResetWorkspaceService
    autoload :CleanupResetService
    autoload :PublicDescMetadataService
    autoload :PublicXmlService
    autoload :PublishMetadataService
    autoload :ThumbnailService
    autoload :Ontology
    autoload :CreativeCommonsLicenseService
    autoload :OpenDataLicenseService
  end

  # Workflow Classes
  module Workflow
    extend ActiveSupport::Autoload
    autoload :Process
    autoload :Document
  end

  eager_load!

  require 'dor/utils/hydrus_shims'
end
