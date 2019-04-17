# frozen_string_literal: true

module Dor
  module Rightsable
    extend ActiveSupport::Concern

    included do
      has_metadata name: 'rightsMetadata', type: Dor::RightsMetadataDS, label: 'Rights metadata'
    end
  end
end
