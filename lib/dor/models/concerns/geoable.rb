# frozen_string_literal: true

module Dor
  module Geoable
    extend ActiveSupport::Concern

    included do
      has_metadata  name: 'geoMetadata',
                    type: Dor::GeoMetadataDS,
                    label: 'Geographic Information Metadata in ISO 19139',
                    control_group: 'M'
    end
  end
end
