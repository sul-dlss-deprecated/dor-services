# frozen_string_literal: true

module Dor
  class ReleaseTagService
    # Determine projects in which an item is released
    # @param [Dor::Item] item to get the release tags for
    # @return [Hash{String => Boolean}] all namespaces, keys are Project name Strings, values are Boolean
    def self.for(item)
      new(item)
    end

    def initialize(item)
      Deprecation.warn(self, "Dor::ReleaseTagService is deprecated and will be removed in dor-services 9.0. (it's moving to dor-services-app)")
      @identity_metadata_service = ReleaseTags::IdentityMetadata.new(item)
      @purl_service = ReleaseTags::Purl.new(pid: item.pid, purl_host: Dor::Config.stacks.document_cache_host)
    end

    # Called in Dor::UpdateMarcRecordService (in dor-services-app too)
    # Determine projects in which an item is released
    # @return [Hash{String => Boolean}] all namespaces, keys are Project name Strings, values are Boolean
    def released_for(skip_live_purl:)
      released_hash = identity_metadata_service.released_for({})
      released_hash = purl_service.released_for(released_hash) unless skip_live_purl
      released_hash
    end

    # Helper method to get the release tags as a nodeset
    # @return [Hash] all release tags and their attributes
    delegate :release_tags, to: :identity_metadata_service

    # Take a hash of tags as obtained via Dor::Item.release_tags and returns the newest tag for each namespace
    # @param tags [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    # @return [Hash] a hash of latest tags for each to value
    delegate :newest_release_tag, to: :identity_metadata_service

    private

    attr_reader :identity_metadata_service, :purl_service
  end
end
