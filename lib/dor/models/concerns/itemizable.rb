# frozen_string_literal: true

module Dor
  module Itemizable
    extend ActiveSupport::Concern

    included do
      has_metadata name: 'contentMetadata', type: Dor::ContentMetadataDS, label: 'Content Metadata', control_group: 'M'
    end
  end
end
