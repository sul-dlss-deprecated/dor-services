module Dor
  class Collection < Dor::Set
    include Releaseable

    has_object_type 'collection'
  end
end
