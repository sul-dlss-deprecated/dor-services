# frozen_string_literal: true

module Dor
  class Abstract < ::ActiveFedora::Base
    extend Deprecation
    self.deprecation_horizon = '8.0'

    has_metadata name: 'provenanceMetadata',
                 type: ProvenanceMetadataDS,
                 label: 'Provenance Metadata'
    has_metadata name: 'rightsMetadata',
                 type: RightsMetadataDS,
                 label: 'Rights metadata'
    has_metadata name: 'events',
                 type: EventsDS,
                 label: 'Events'
    has_metadata name: 'versionMetadata',
                 type: VersionMetadataDS,
                 label: 'Version Metadata',
                 autocreate: true
    has_metadata name: 'DC',
                 type: SimpleDublinCoreDs,
                 label: 'Dublin Core Record for self object'
    has_metadata name: 'identityMetadata',
                 type: Dor::IdentityMetadataDS,
                 label: 'Identity Metadata'
    has_metadata name: 'descMetadata',
                 type: Dor::DescMetadataDS,
                 label: 'Descriptive Metadata',
                 control_group: 'M'

    belongs_to :admin_policy_object,
               property: :is_governed_by,
               class_name: 'Dor::AdminPolicyObject'
    has_and_belongs_to_many :collections,
                            property: :is_member_of_collection,
                            class_name: 'Dor::Collection'
    has_and_belongs_to_many :sets,
                            property: :is_member_of,
                            class_name: 'Dor::Collection'

    class_attribute :object_type

    def self.has_object_type(str)
      self.object_type = str
      Dor.registered_classes[str] = self
    end

    # Overrides the method in ActiveFedora to mint a pid using SURI rather
    # than the default Fedora sequence
    def self.assign_pid(_obj)
      return Dor::SuriService.mint_id if Dor::Config.suri.mint_ids

      super
    end

    # Overrides the method in ActiveFedora
    def to_solr
      raise 'this should never be called'
    end

    # Override ActiveFedora::Core#adapt_to_cmodel (used with associations, among other places) to
    # preferentially use the objectType asserted in the identityMetadata.
    def adapt_to_cmodel
      object_type = identityMetadata.objectType.first
      object_class = Dor.registered_classes[object_type]

      if object_class
        instance_of?(object_class) ? self : adapt_to(object_class)
      else
        begin
          super
        rescue ActiveFedora::ModelNotAsserted
          adapt_to(Dor::Item)
        end
      end
    end

    # a regex that can be used to identify the last part of a druid (e.g. oo000oo0001)
    # @return [Regex] a regular expression to identify the ID part of the druid
    def pid_regex
      /[a-zA-Z]{2}[0-9]{3}[a-zA-Z]{2}[0-9]{4}/
    end
    deprecation_deprecate pid_regex: 'use PidUtils::PID_REGEX instead'

    # a regex that can be used to identify a full druid with prefix (e.g. druid:oo000oo0001)
    # @return [Regex] a regular expression to identify a full druid
    def druid_regex
      /druid:#{pid_regex}/
    end
    deprecation_deprecate druid_regex: 'will be removed without replacement'

    # Since purl does not use the druid: prefix but much of dor does, use this function to strip the druid: if needed
    # @return [String] the druid sans the druid: or if there was no druid: prefix, the entire string you passed
    def remove_druid_prefix(druid = id)
      PidUtils.remove_druid_prefix(druid)
    end
    deprecation_deprecate remove_druid_prefix: 'use PidUtils.remove_druid_prefix instead'

    # This is used by Argo and the MergeService
    # @return [Boolean] true if the object is in a state that allows it to be modified.
    #  States that will allow modification are: has not been submitted for accessioning, has an open version or has sdr-ingest set to hold
    # @todo this could be a workflow service endpoint
    def allows_modification?
      Dor::StateService.new(pid).allows_modification?
    end
    deprecation_deprecate allows_modification?: 'use Dor::StateService#allows_modification? instead'

    def current_version
      versionMetadata.current_version_id
    end

    delegate :full_title, :stanford_mods, to: :descMetadata
    delegate :rights, to: :rightsMetadata
    delegate :catkey, :catkey=, :source_id, :source_id=,
             :objectId, :objectId=, :objectCreator, :objectCreator=,
             :objectLabel, :objectLabel=, :objectType, :objectType=,
             :other_ids=, :otherId, :tag=, :tags, :release_tags,
             :previous_catkeys, :content_type_tag, to: :identityMetadata

    def read_rights=(rights)
      rightsMetadata.set_read_rights(rights)
      unshelve_and_unpublish if rights == 'dark'
    end
    alias set_read_rights read_rights=
    deprecation_deprecate set_read_rights: 'Use read_rights= instead'

    def add_collection(collection_or_druid)
      collection_manager.add(collection_or_druid)
    end

    def remove_collection(collection_or_druid)
      collection_manager.remove(collection_or_druid)
    end

    # set the rights metadata datastream to the content of the APO's default object rights
    def reapply_admin_policy_object_defaults
      rightsMetadata.content = admin_policy_object.defaultObjectRights.content
    end
    alias reapplyAdminPolicyObjectDefaults reapply_admin_policy_object_defaults
    deprecation_deprecate reapplyAdminPolicyObjectDefaults: 'Use reapply_admin_policy_object_defaults instead'

    private

    def unshelve_and_unpublish
      contentMetadata.unshelve_and_unpublish if respond_to? :contentMetadata
    end

    def collection_manager
      CollectionService.new(self)
    end
  end
end
