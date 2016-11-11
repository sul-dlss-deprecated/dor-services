module Dor
  class Abstract < Dor::Base
    include Describable
    include Processable
    include Versionable
  end
end
