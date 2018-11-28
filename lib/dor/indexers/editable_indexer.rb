# frozen_string_literal: true

module Dor
  class EditableIndexer
    include SolrDocHelper

    attr_reader :resource
    def initialize(resource:)
      @resource = resource
    end

    def to_solr
      {}.tap do |solr_doc|
        add_solr_value(solr_doc, 'default_rights', default_rights_for_indexing, :string, [:symbol])
        add_solr_value(solr_doc, 'agreement', resource.agreement, :string, [:symbol]) if resource.agreement_object
        add_solr_value(solr_doc, 'default_use_license_machine', resource.use_license, :string, [:stored_sortable])
      end
    end

    # @return [String] A description of the rights defined in the default object rights datastream. Can be 'Stanford', 'World', 'Dark' or 'None'
    def default_rights_for_indexing
      RightsMetadataDS::RIGHTS_TYPE_CODES.fetch(resource.default_rights, 'Unrecognized default rights value')
    end
  end
end
