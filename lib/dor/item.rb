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
  end
  
  class Item < ::ActiveFedora::Base
    include BasicItem
  end
end