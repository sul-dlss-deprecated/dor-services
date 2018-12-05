# frozen_string_literal: true

module Dor
  class Abstract < ::ActiveFedora::Base
    include Identifiable
    include Eventable
    include Governable
    include Rightsable
    include Describable
    include Versionable
    include Processable
    include Preservable

    class_attribute :resource_indexer

    def to_solr
      resource_indexer.new(resource: self).to_solr
    end
  end
end
