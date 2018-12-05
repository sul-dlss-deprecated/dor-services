# frozen_string_literal: true

module Dor
  module Releaseable
    extend ActiveSupport::Concern

    # Called in Dor::UpdateMarcRecordService (in dor-services-app too)
    # Determine projects in which an item is released
    # @param [Boolean] skip_live_purl set true to skip requesting from purl backend
    # @return [Hash{String => Boolean}] all namespaces, keys are Project name Strings, values are Boolean
    def released_for(skip_live_purl = false)
      releases.released_for(skip_live_purl: skip_live_purl)
    end

    def releases
      @releases ||= ReleaseTagService.for(self)
    end
  end
end
