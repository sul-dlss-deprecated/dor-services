module Dor
  class Item < Base
    include Identifiable
    include Processable
    include Governable
    include Describable
    include Publishable
    include Shelvable
    include Preservable
  end
end