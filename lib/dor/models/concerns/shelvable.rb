# frozen_string_literal: true

module Dor
  module Shelvable
    extend Deprecation
    extend ActiveSupport::Concern
    self.deprecation_horizon = 'dor-services version 7.0.0'

    # Push file changes for shelve-able files into the stacks
    def shelve
      ShelvingService.shelve(self)
    end
    deprecation_deprecate shelve: 'Use ShelvingService.shelve(work) instead'
  end
end
