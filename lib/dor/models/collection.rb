module Dor
  class Collection < ::ActiveFedora::Base
    include Identifiable
    include Processable
    include Governable
    include Describable
    include Publishable
    include Versionable

    has_relationship 'member', :is_member_of_collection, :inbound => true
    has_object_type 'collection'
  end
end
