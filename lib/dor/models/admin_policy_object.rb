# frozen_string_literal: true

module Dor
  class AdminPolicyObject < Dor::Abstract
    has_many :things, property: :is_governed_by, class_name: 'ActiveFedora::Base'
    has_object_type 'adminPolicy'
    has_metadata name: 'administrativeMetadata', type: Dor::AdministrativeMetadataDS, label: 'Administrative Metadata'
    has_metadata name: 'roleMetadata',           type: Dor::RoleMetadataDS,           label: 'Role Metadata'
    has_metadata name: 'defaultObjectRights',    type: Dor::DefaultObjectRightsDS,    label: 'Default Object Rights'
    belongs_to :agreement_object, property: :referencesAgreement, class_name: 'Dor::Agreement'

    delegate :add_roleplayer, :purge_roles, :roles, to: :roleMetadata
    delegate :mods_title, :mods_title=, to: :descMetadata
    delegate :default_collections, :add_default_collection, :remove_default_collection,
             :metadata_source, :metadata_source=,
             :default_workflows, :default_workflow=,
             :desc_metadata_source, :desc_metadata_source=,
             :desc_metadata_format, :desc_metadata_format=, to: :administrativeMetadata

    delegate :use_statement, :use_statement=,
             :copyright_statement, :copyright_statement=,
             :creative_commons_license, :creative_commons_license_human,
             :open_data_commons_license, :open_data_commons_license_human,
             :use_license, :use_license_uri, :use_license_human,
             :creative_commons_license=, :creative_commons_license_human=,
             :open_data_commons_license=, :open_data_commons_license_human=,
             :use_license=, :default_rights, :default_rights=, to: :defaultObjectRights

    def agreement
      agreement_object ? agreement_object.pid : ''
    end

    def agreement=(val)
      raise ArgumentError, 'agreement must have a valid druid' if val.blank?

      self.agreement_object = Dor.find val.to_s, cast: true
    end
  end
end
