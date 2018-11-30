# frozen_string_literal: true

require 'open-uri'
require 'retries'

module Dor
  module Releaseable
    extend ActiveSupport::Concern
    extend Deprecation
    self.deprecation_horizon = 'dor-services version 7.0.0'

    # Add release tags to an item and initialize the item release workflow
    # Each tag should be of the form !{:tag => 'Fitch : Batch2', :what => 'self', :to => 'Searchworks', :who => 'petucket', :release => true}
    # @param release_tags [Hash, Array<Hash>] hash of a single release tag or an array of many such hashes
    # @raise [ArgumentError] Raised if the tags are improperly supplied
    def add_release_nodes_and_start_releaseWF(release_tags)
      release_tags = [release_tags] unless release_tags.is_a?(Array)

      # Add in each tag
      release_tags.each do |r_tag|
        add_release_node(r_tag[:release], r_tag)
      end

      # Save item to dor so the robots work with the latest data
      save
      create_workflow('releaseWF')
    end
    deprecation_deprecate add_release_nodes_and_start_releaseWF: 'No longer used by any DLSS code'

    # Called in Dor::UpdateMarcRecordService (in dor-services-app too)
    # Determine projects in which an item is released
    # @param [Boolean] skip_live_purl set true to skip requesting from purl backend
    # @return [Hash{String => Boolean}] all namespaces, keys are Project name Strings, values are Boolean
    def released_for(skip_live_purl = false)
      releases.released_for(skip_live_purl: skip_live_purl)
    end

    def releases
      @releases ||= ReleaseTagService.for(self)
    end

    # Determine if the supplied tag is a valid release tag that meets all requirements
    #
    # @param attrs [hash] A hash of attributes for the tag, must contain: :when, a ISO 8601 timestamp; :who, to identify who or what added the tag; and :to, a string identifying the release target
    # @raise [RuntimeError]  Raises an error of the first fault in the release tag
    # @return [Boolean] Returns true if no errors found
    def valid_release_attributes_and_tag(tag, attrs = {})
      raise ArgumentError, ':when is not iso8601' if attrs[:when].match('\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z').nil?

      %i[who to what].each do |check_attr|
        raise ArgumentError, "#{check_attr} not supplied as a String" if attrs[check_attr].class != String
      end

      what_correct = false
      %w(self collection).each do |allowed_what_value|
        what_correct = true if attrs[:what] == allowed_what_value
      end
      raise ArgumentError, ':what must be self or collection' unless what_correct
      raise ArgumentError, 'the value set for this tag is not a boolean' if !!tag != tag # rubocop:disable Style/DoubleNegation

      true
    end
    deprecation_deprecate valid_release_attributes_and_tag: 'No longer used by any DLSS code'

    # TODO: Move to dor-services-app
    # Add a release node for the item
    # Will use the current time if timestamp not supplied. You can supply a timestap for correcting history, etc if desired
    # Timestamp will be calculated by the function
    #
    # @param release [Boolean] True or false for the release node
    # @param attrs [hash]  A hash of any attributes to be placed onto the tag
    # @return [Nokogiri::XML::Element] the tag added if successful
    # @raise [ArgumentError] Raised if attributes are improperly supplied
    #
    # @example
    #  item.add_release_node(true,{:what=>'self',:to=>'Searchworks',:who=>'petucket'})
    def add_release_node(release, attrs = {})
      allowed_release_attributes = %i[what to who when] # any other release attributes sent in will be rejected and not stored
      identity_metadata_ds = identityMetadata
      attrs.delete_if { |key, _value| !allowed_release_attributes.include?(key) }
      attrs[:when] = Time.now.utc.iso8601 if attrs[:when].nil? # add the timestamp
      valid_release_attributes(release, attrs)
      identity_metadata_ds.add_value(:release, release.to_s, attrs)
    end

    # TODO: Move to dor-services-app
    # Determine if the supplied tag is a valid release node that meets all requirements
    #
    # @param tag [Boolean] True or false for the release node
    # @param attrs [hash] A hash of attributes for the tag, must contain :when, a ISO 8601 timestamp and :who to identify who or what added the tag, :to,
    # @raise [ArgumentError]  Raises an error of the first fault in the release tag
    # @return [Boolean] Returns true if no errors found
    def valid_release_attributes(tag, attrs = {})
      raise ArgumentError, ':when is not iso8601' if attrs[:when].match('\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z').nil?

      %i[who to what].each do |check_attr|
        raise ArgumentError, "#{check_attr} not supplied as a String" if attrs[check_attr].class != String
      end
      raise ArgumentError, ':what must be self or collection' unless %w(self collection).include? attrs[:what]
      raise ArgumentError, 'the value set for this tag is not a boolean' unless [true, false].include? tag

      true
    end
  end
end
