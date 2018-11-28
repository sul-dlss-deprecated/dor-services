module Dor
  # Indexing provided by ActiveFedora
  class DataIndexer
    include ActiveFedora::Indexing

    attr_reader :resource
    def initialize(resource:)
      @resource = resource
    end

    delegate :create_date, :modified_date, :state, :pid, :inner_object,
             :datastreams, :relationships, to: :resource
  end
end
