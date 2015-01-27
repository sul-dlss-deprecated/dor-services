module Dor
  module BasicItem
    extend ActiveSupport::Concern
    
    include Identifiable
    include Processable
    include Governable
    include Describable
    include Publishable
    include Shelvable
    include Embargoable
    include Preservable
    include Assembleable
    include Versionable
    include Contentable
    include Geoable
    include Releaseable
    
  end
  
  class Abstract < ::ActiveFedora::Base
    include Identifiable
  end

  class Item < ::ActiveFedora::Base
    include BasicItem
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
# Upgradable   = Remediation of existing objects when content standards change.
# Geoable      = Descriptive metadata for GIS in ISO 19139/19110.

# Required for all DOR objects:
#   - Identifiable
#   - Governable
#   - Describable
