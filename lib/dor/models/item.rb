module Dor
  module BasicItem
    extend ActiveSupport::Concern
    
    include Identifiable
    include Processable
    include Governable
    include Describable
    include Publishable
    include Shelvable
    include Embargoable
    include Preservable
    include Assembleable
  end
  
  class Abstract < ::ActiveFedora::Base
    include Identifiable
  end

  class Item < ::ActiveFedora::Base
    include BasicItem
    has_object_type 'item'
  end
end