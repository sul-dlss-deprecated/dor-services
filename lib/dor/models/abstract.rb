# frozen_string_literal: true

module Dor
  class Abstract < ::ActiveFedora::Base
    include Identifiable
    include Governable
    include Describable

    has_metadata name: 'provenanceMetadata',
                 type: ProvenanceMetadataDS,
                 label: 'Provenance Metadata'
    has_metadata name: 'workflows',
                 type: WorkflowDs,
                 label: 'Workflows',
                 control_group: 'E',
                 autocreate: true
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

    class_attribute :resource_indexer

    def to_solr
      resource_indexer.new(resource: self).to_solr
    end

    def current_version
      versionMetadata.current_version_id
    end

    # This is used by Argo and the MergeService
    # @return [Boolean] true if the object is in a state that allows it to be modified.
    #  States that will allow modification are: has not been submitted for accessioning, has an open version or has sdr-ingest set to hold
    # @todo this could be a workflow service endpoint
    def allows_modification?
      client = Dor::Config.workflow.client
      !client.lifecycle('dor', pid, 'submitted') ||
        client.active_lifecycle('dor', pid, 'opened') ||
        client.workflow_status('dor', pid, 'accessionWF', 'sdr-ingest-transfer') == 'hold'
    end
  end
end
