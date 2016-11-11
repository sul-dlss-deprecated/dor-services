module Dor
  class Base < ::ActiveFedora::Base
    include Identifiable
    include Eventable
    include Governable
    include Rightsable
  end
end
