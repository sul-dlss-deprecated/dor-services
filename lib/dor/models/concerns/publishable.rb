# frozen_string_literal: true

module Dor
  # Transfer of metadata to discovery and access systems.
  module Publishable
    extend ActiveSupport::Concern
    extend Deprecation
    self.deprecation_horizon = '8.0'

    # strips away the relationships that should not be shown in public desc metadata
    # @return [Nokogiri::XML]
    def public_relationships
      PublishedRelationshipsFilter.new(self).xml
    end
    deprecation_deprecate public_relationships: 'use PublishedRelationshipsFilter instead'
  end
end
