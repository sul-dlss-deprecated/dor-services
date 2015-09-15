require 'dor/utils/sdr_client'

module Dor
  module Versionable
    extend ActiveSupport::Concern
    include Processable # implies Upgradable

    included do
      has_metadata :name => 'versionMetadata', :type => Dor::VersionMetadataDS, :label => 'Version Metadata', :autocreate => true
    end

    # Increments the version number and initializes versioningWF for the object
    # @param [Hash] opts optional params
    # @option opts [Boolean] :assume_accessioned If true, does not check whether object has been accessioned.
    # @option opts [Boolean] :create_workflows_ds If false, initialize_workflow() will not initialize the workflows datastream.
    # @option opts [Hash] :vers_md_upd_info If present, used to add to the events datastream and set the desc and significance on the versionMetadata datastream
    # @raise [Dor::Exception] if the object hasn't been accessioned, or if a version is already opened
    def open_new_version(opts = {})
      # During local development, we need a way to open a new version even if the object has not been accessioned.
      raise(Dor::Exception, 'Object net yet accessioned') unless
        opts[:assume_accessioned] || Dor::WorkflowService.get_lifecycle('dor', pid, 'accessioned')
      raise Dor::Exception, 'Object already opened for versioning' if new_version_open?
      raise Dor::Exception, 'Object currently being accessioned' if Dor::WorkflowService.get_active_lifecycle('dor', pid, 'submitted')

      sdr_version = Sdr::Client.current_version pid

      vmd_ds = datastreams['versionMetadata']
      vmd_ds.sync_then_increment_version sdr_version
      vmd_ds.content = vmd_ds.ng_xml.to_s
      vmd_ds.save unless self.new_object?

      k = :create_workflows_ds
      if opts.key?(k)
        # During local development, Hydrus (or another app w/ local Fedora) does not want to initialize workflows datastream.
        initialize_workflow('versioningWF', opts[k])
      else
        initialize_workflow('versioningWF')
      end

      vmd_upd_info = opts[:vers_md_upd_info]
      return unless vmd_upd_info
      datastreams['events'].add_event('open', vmd_upd_info[:opening_user_name], "Version #{vmd_ds.current_version_id} opened")
      vmd_ds.update_current_version({:description => vmd_upd_info[:description], :significance => vmd_upd_info[:significance].to_sym})
      save
    end

    def current_version
      datastreams['versionMetadata'].current_version_id
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
      unless opts.empty?
        datastreams['versionMetadata'].update_current_version opts
        datastreams['versionMetadata'].save
      end

      raise Dor::Exception, 'latest version in versionMetadata requires tag and description before it can be closed' unless datastreams['versionMetadata'].current_version_closeable?
      raise Dor::Exception, 'Trying to close version on an object not opened for versioning' unless new_version_open?
      raise Dor::Exception, 'accessionWF already created for versioned object' if Dor::WorkflowService.get_active_lifecycle('dor', pid, 'submitted')

      Dor::WorkflowService.close_version 'dor', pid, opts.fetch(:start_accession, true)  # Default to creating accessionWF when calling close_version
    end

    # @return [Boolean] true if 'opened' lifecycle is active, false otherwise
    def new_version_open?
      return true if Dor::WorkflowService.get_active_lifecycle('dor', pid, 'opened')
      false
    end

    # @return [Boolean] true if the object is in a state that allows it to be modified. States that will allow modification are: has not been submitted for accessioning, has an open version or has sdr-ingest set to hold
    def allows_modification?
      if Dor::WorkflowService.get_lifecycle('dor', pid, 'submitted') && !new_version_open? && Dor::WorkflowService.get_workflow_status('dor', pid, 'accessionWF', 'sdr-ingest-transfer') != 'hold'
        false
      else
        true
      end
    end

    # Following chart of processes on this consul page: https://consul.stanford.edu/display/chimera/Versioning+workflows
    alias_method :start_version,  :open_new_version
    alias_method :submit_version, :close_version

  end
end
