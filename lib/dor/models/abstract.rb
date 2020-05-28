# frozen_string_literal: true

module Dor
  class Abstract < ::ActiveFedora::Base
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

    def current_version
      versionMetadata.current_version_id
    end

    delegate :full_title, :stanford_mods, to: :descMetadata
    delegate :rights, to: :rightsMetadata
    delegate :catkey, :catkey=, :source_id, :source_id=, :barcode, :barcode=,
             :objectId, :objectId=, :objectCreator, :objectCreator=,
             :objectLabel, :objectLabel=, :objectType, :objectType=,
             :other_ids=, :otherId, :release_tags, :previous_catkeys,
             to: :identityMetadata

    def read_rights=(rights)
      rightsMetadata.set_read_rights(rights)
      unshelve_and_unpublish if rights == 'dark'
    end

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

    private

    def unshelve_and_unpublish
      contentMetadata.unshelve_and_unpublish if respond_to? :contentMetadata
    end

    def collection_manager
      CollectionService.new(self)
    end
  end
end
