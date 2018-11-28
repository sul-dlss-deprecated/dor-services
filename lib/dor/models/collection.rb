module Dor
  class Collection < Dor::Set
    include Releaseable

    has_object_type 'collection'

    self.resource_indexer = CompositeIndexer.new(
      DataIndexer,
      DescribableIndexer,
      IdentifiableIndexer,
      ProcessableIndexer,
      ReleasableIndexer
    )
  end
end
