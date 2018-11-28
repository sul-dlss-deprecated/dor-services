# frozen_string_literal: true

module Hydrus
  # These shims allow DOR to interact seamlessly with Hydrus' custom models
  class Item < Dor::Item
  end

  class Collection < Dor::Collection
  end

  class AdminPolicyObject < Dor::AdminPolicyObject
  end
end
