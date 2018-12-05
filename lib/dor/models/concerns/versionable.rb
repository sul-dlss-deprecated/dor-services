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
    def allows_modification?
      if Dor::Config.workflow.client.lifecycle('dor', pid, 'submitted') &&
         !VersionService.new(self).open? &&
         Dor::Config.workflow.client.workflow_status('dor', pid, 'accessionWF', 'sdr-ingest-transfer') != 'hold'
        false
      else
        true
      end
    end
  end
end
