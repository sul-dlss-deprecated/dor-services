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
    # to adapt it to.
    # @param [String] pid The object's PID
    # @return [Object] the ActiveFedora-modeled object
    def find(pid, _opts = {})
      Dor::Abstract.find pid, cast: true
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
    autoload :WorkflowIndexer
    autoload :WorkflowsIndexer
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
    autoload :Embargoable
    autoload :Preservable
    autoload :Eventable
    autoload :Versionable
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
      autoload :WorkflowSolrDocument
    end
  end

  # Services
  autoload_under 'services' do
    autoload :CleanupService
    autoload :CreateWorkflowService
    autoload :CreativeCommonsLicenseService
    autoload :DecommissionService
    autoload :DublinCoreService
    autoload :IndexingService
    autoload :MetadataService
    autoload :Ontology
    autoload :OpenDataLicenseService
    autoload :PublicDescMetadataService
    autoload :RegistrationService
    autoload :ReleaseTagService
    autoload :SearchService
    autoload :StatusService
    autoload :SuriService
    autoload :TagService
    autoload :ThumbnailService
  end

  # Workflow Classes
  module Workflow
    extend ActiveSupport::Autoload
    autoload :Process
    autoload :Document
  end

  eager_load!

  require 'dor/utils/hydrus_shims'
  require 'dor/workflow/client'
end
