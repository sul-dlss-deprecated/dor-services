# frozen_string_literal: true

module Dor
  class Set < Dor::Abstract
    has_many :members, property: :is_member_of_collection, class_name: 'ActiveFedora::Base'
    has_object_type 'set'

    self.resource_indexer = CompositeIndexer.new(
      DataIndexer,
      DescribableIndexer,
      IdentifiableIndexer,
      ProcessableIndexer,
      WorkflowsIndexer
    )
  end
end
