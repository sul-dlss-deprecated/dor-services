module Dor
  class Set < ::ActiveFedora::Base
    include Identifiable
    include Processable
    include Governable
    include Describable
    include Publishable

    has_many :members, :property => :is_member_of_collection, :inbound => true, :class_name => "ActiveFedora::Base"
    has_object_type 'set'
  end
end
