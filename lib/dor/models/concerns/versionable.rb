# frozen_string_literal: true

module Dor
  module Versionable
    extend ActiveSupport::Concern

    included do
      has_metadata name: 'versionMetadata', type: Dor::VersionMetadataDS, label: 'Version Metadata', autocreate: true
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
