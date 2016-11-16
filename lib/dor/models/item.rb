module Dor
  class Item < Dor::Abstract
    include Shelvable
    include Embargoable
    include Publishable
    include Itemizable
    include Preservable
    include Assembleable
    include Contentable
    include Geoable
    include Releaseable

    has_object_type 'item'
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
