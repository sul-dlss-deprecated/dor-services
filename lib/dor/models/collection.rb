module Dor
  class Collection < ::ActiveFedora::Base
    include Identifiable
    include Processable
    include Governable
    include Describable
    include Publishable
    include Versionable
    include Releaseable

    has_many :members, :property => :is_member_of_collection, :class_name => 'ActiveFedora::Base'
    has_object_type 'collection'
  end
end
