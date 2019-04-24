# frozen_string_literal: true

module Dor
  class Item < Dor::Abstract
    include Embargoable
    include Releaseable

    has_object_type 'item'

    self.resource_indexer = CompositeIndexer.new(
      DataIndexer,
      DescribableIndexer,
      IdentifiableIndexer,
      ProcessableIndexer,
      ReleasableIndexer,
      WorkflowsIndexer
    )

    has_metadata name: 'technicalMetadata',
                 type: TechnicalMetadataDS,
                 label: 'Technical Metadata',
                 control_group: 'M'
    has_metadata name: 'contentMetadata',
                 type: Dor::ContentMetadataDS,
                 label: 'Content Metadata',
                 control_group: 'M'
    has_metadata name: 'geoMetadata',
                 type: Dor::GeoMetadataDS,
                 label: 'Geographic Information Metadata in ISO 19139',
                 control_group: 'M'
  end
end
