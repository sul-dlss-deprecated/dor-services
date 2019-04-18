# frozen_string_literal: true

module Dor
  class Item < Dor::Abstract
    include Embargoable
    include Publishable
    include Geoable
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

    has_metadata name: 'technicalMetadata', type: TechnicalMetadataDS, label: 'Technical Metadata', control_group: 'M'
    has_metadata name: 'contentMetadata', type: Dor::ContentMetadataDS, label: 'Content Metadata', control_group: 'M'
  end
end

# Describable  = Descriptive metadata.
# Embargoable  = Time limits and processes for embargoed materials.
# Governable   = Relationships to collections and codified administrative policies.
# Identifiable = Object identity and source metadata.
# Itemizable   = Hierarchical content metadata.
# Preservable  = Provenance and technical metadata; preservation repository transfer.
# Processable  = Workflow.
# Publishable  = Transfer of metadata to discovery and access systems.
# Shelvable    = Transfer of content to digital stacks.
# Geoable      = Descriptive metadata for GIS in ISO 19139/19110.

# Required for all DOR objects:
#   - Identifiable
#   - Governable
#   - Describable
