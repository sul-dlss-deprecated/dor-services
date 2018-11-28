# frozen_string_literal: true

module Dor
  # Indexing provided by ActiveFedora
  class DataIndexer
    include ActiveFedora::Indexing

    attr_reader :resource
    def initialize(resource:)
      @resource = resource
    end

    # we need to override this until https://github.com/samvera/active_fedora/pull/1371
    # has been released
    def to_solr(solr_doc = {}, opts = {})
      super.tap do |doc|
        doc['active_fedora_model_ssi'] = has_model
      end
    end

    # rubocop:disable Naming/PredicateName
    def has_model
      resource.class.inspect
    end
    # rubocop:enable Naming/PredicateName

    delegate :create_date, :modified_date, :state, :pid, :inner_object,
             :datastreams, :relationships, to: :resource
  end
end
