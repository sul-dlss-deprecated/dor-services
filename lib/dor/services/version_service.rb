# frozen_string_literal: true

module Dor
  # Open and close versions
  class VersionService
    def self.open(work, opts = {})
      new(work).open(opts)
    end

    def self.close(work, opts = {})
      new(work).close(opts)
    end

    def initialize(work)
      @work = work
    end

    # Increments the version number and initializes versioningWF for the object
    # @param [Hash] opts optional params
    # @option opts [Boolean] :assume_accessioned If true, does not check whether object has been accessioned.
    # @option opts [Boolean] :create_workflows_ds If false, create_workflow() will not initialize the workflows datastream.
    # @option opts [Hash] :vers_md_upd_info If present, used to add to the events datastream and set the desc and significance on the versionMetadata datastream
    # @raise [Dor::Exception] if the object hasn't been accessioned, or if a version is already opened
    def open(opts = {})
      # During local development, we need a way to open a new version even if the object has not been accessioned.
      raise(Dor::Exception, 'Object net yet accessioned') unless
        opts[:assume_accessioned] || Dor::Config.workflow.client.get_lifecycle('dor', work.pid, 'accessioned')
      raise Dor::Exception, 'Object already opened for versioning' if open?
      raise Dor::Exception, 'Object currently being accessioned' if Dor::Config.workflow.client.get_active_lifecycle('dor', work.pid, 'submitted')

      sdr_version = Sdr::Client.current_version work.pid

      vmd_ds = work.versionMetadata
      vmd_ds.sync_then_increment_version sdr_version
      vmd_ds.save unless work.new_record?

      k = :create_workflows_ds
      if opts.key?(k)
        # During local development, Hydrus (or another app w/ local Fedora) does not want to initialize workflows datastream.
        work.create_workflow('versioningWF', opts[k])
      else
        work.create_workflow('versioningWF')
      end

      vmd_upd_info = opts[:vers_md_upd_info]
      return unless vmd_upd_info

      work.events.add_event('open', vmd_upd_info[:opening_user_name], "Version #{vmd_ds.current_version_id} opened")
      vmd_ds.update_current_version(description: vmd_upd_info[:description], significance: vmd_upd_info[:significance].to_sym)
      work.save
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
    def close(opts = {})
      unless opts.empty?
        work.versionMetadata.update_current_version opts
        work.versionMetadata.save
      end

      raise Dor::Exception, 'latest version in versionMetadata requires tag and description before it can be closed' unless work.versionMetadata.current_version_closeable?
      raise Dor::Exception, 'Trying to close version on an object not opened for versioning' unless open?
      raise Dor::Exception, 'accessionWF already created for versioned object' if Dor::Config.workflow.client.get_active_lifecycle('dor', work.pid, 'submitted')

      Dor::Config.workflow.client.close_version 'dor', work.pid, opts.fetch(:start_accession, true) # Default to creating accessionWF when calling close_version
    end

    # @return [Boolean] true if 'opened' lifecycle is active, false otherwise
    def open?
      return true if Dor::Config.workflow.client.get_active_lifecycle('dor', work.pid, 'opened')

      false
    end

    attr_reader :work
  end
end
