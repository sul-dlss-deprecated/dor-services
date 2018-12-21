# frozen_string_literal: true

module Dor
  ## This is basically used just by APOs.  Arguably "editable" is the wrong name.
  module Editable
    extend ActiveSupport::Concern

    included do
      belongs_to :agreement_object, property: :referencesAgreement, class_name: 'Dor::Item'
    end

    CREATIVE_COMMONS_USE_LICENSES = ActiveSupport::Deprecation::DeprecatedConstantProxy.new('CREATIVE_COMMONS_USE_LICENSES', 'Dor::CreativeCommonsLicenseService')
    OPEN_DATA_COMMONS_USE_LICENSES = ActiveSupport::Deprecation::DeprecatedConstantProxy.new('OPEN_DATA_COMMONS_USE_LICENSES', 'Dor::OpenDataLicenseService')

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
