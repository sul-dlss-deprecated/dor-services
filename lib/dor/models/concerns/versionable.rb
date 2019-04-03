# frozen_string_literal: true

module Dor
  module Versionable
    extend ActiveSupport::Concern
    extend Deprecation
    self.deprecation_horizon = 'dor-services version 7.0.0'

    included do
      has_metadata name: 'versionMetadata', type: Dor::VersionMetadataDS, label: 'Version Metadata', autocreate: true
    end

    # Increments the version number and initializes versioningWF for the object
    # @param [Hash] opts optional params
    # @option opts [Boolean] :assume_accessioned If true, does not check whether object has been accessioned.
    # @option opts [Boolean] :create_workflows_ds If false, create_workflow() will not initialize the workflows datastream.
    # @option opts [Hash] :vers_md_upd_info If present, used to add to the events datastream and set the desc and significance on the versionMetadata datastream
    # @raise [Dor::Exception] if the object hasn't been accessioned, or if a version is already opened
    def open_new_version(opts = {})
      VersionService.open(self, opts)
    end
    deprecation_deprecate open_new_version: 'Use Dor::Services::Client.object(object_identifier).open_new_version(**params) instead'

    def current_version
      versionMetadata.current_version_id
    end

    # Sets versioningWF:submit-version to completed and initiates accessionWF for the object
    # @param [Hash] opts optional params
    # @option opts [String] :description describes the version change
    # @option opts [Symbol] :significance which part of the version tag to increment
    #  :major, :minor, :admin (see Dor::VersionTag#increment)
    # @option opts [String] :version_num version number to archive rows with. Otherwise, current version is used
    # @option opts [Boolean] :start_accesion set to true if you want accessioning to start (default), false otherwise
    # @raise [Dor::Exception] if the object hasn't been opened for versioning, or if accessionWF has
    #   already been instantiated or the current version is missing a tag or description
    def close_version(opts = {})
      VersionService.close(self, opts)
    end
    deprecation_deprecate close_version: 'Use Dor::Services::Client.object(object_identifier).close_version(**params) instead'

    # @return [Boolean] true if 'opened' lifecycle is active, false otherwise
    def new_version_open?
      VersionService.new(self).open?
    end
    deprecation_deprecate new_version_open?: 'Use VersionService.open? instead'

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

    # Following chart of processes on this consul page: https://consul.stanford.edu/display/chimera/Versioning+workflows
    def start_version
      open_new_version
    end
    deprecation_deprecate start_version: 'Use Dor::Services::Client.object(object_identifier).open_new_version(**params) instead'

    def submit_version
      close_version
    end
    deprecation_deprecate submit_version: 'Use Dor::Services::Client.object(object_identifier).close_version(**params) instead'
  end
end
