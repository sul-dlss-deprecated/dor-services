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
  end
end
