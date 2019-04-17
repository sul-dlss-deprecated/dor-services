# frozen_string_literal: true

module Dor
  module Preservable
    extend ActiveSupport::Concern

    included do
      has_metadata name: 'provenanceMetadata', type: ProvenanceMetadataDS, label: 'Provenance Metadata'
    end
  end
end
