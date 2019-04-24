# frozen_string_literal: true

module Dor
  class Collection < Dor::Set
    has_object_type 'collection'

    self.resource_indexer = CompositeIndexer.new(
      DataIndexer,
      DescribableIndexer,
      IdentifiableIndexer,
      ProcessableIndexer,
      ReleasableIndexer,
      WorkflowsIndexer
    )
  end
end
