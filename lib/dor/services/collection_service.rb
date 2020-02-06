# frozen_string_literal: true

module Dor
  # Adds and removes collections to and from objects
  # Collections are added as Collections and Sets.
  class CollectionService
    def initialize(obj)
      @obj = obj
    end

    def add(collection_or_druid)
      collection = dereference(collection_or_druid)
      obj.collections << collection
      obj.sets << collection
    end

    def remove(collection_or_druid)
      collection = dereference(collection_or_druid)
      obj.collections.delete(collection)
      obj.sets.delete(collection)
    end

    private

    attr_reader :obj

    def dereference(collection_or_druid)
      case collection_or_druid
      when String
        Dor::Collection.find(collection_or_druid)
      when Dor::Collection
        collection_or_druid
      end
    end
  end
end
