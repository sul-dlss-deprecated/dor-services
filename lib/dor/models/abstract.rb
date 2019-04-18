# frozen_string_literal: true

module Dor
  class Abstract < ::ActiveFedora::Base
    include Identifiable
    include Eventable
    include Governable
    include Rightsable
    include Describable
    include Versionable

    has_metadata name: 'provenanceMetadata',
                 type: ProvenanceMetadataDS,
                 label: 'Provenance Metadata'
    has_metadata name: 'workflows',
                 type: Dor::WorkflowDs,
                 label: 'Workflows',
                 control_group: 'E',
                 autocreate: true

    class_attribute :resource_indexer

    def to_solr
      resource_indexer.new(resource: self).to_solr
    end
  end
end
