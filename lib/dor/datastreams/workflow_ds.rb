# frozen_string_literal: true

module Dor
  # Represents the datastream that just holds the location of the workflow service
  class WorkflowDs < ActiveFedora::Datastream
    before_save :build_location

    # Called before saving, but after a pid has been assigned
    def build_location
      return unless new?

      self.dsLocation = File.join(Dor::Config.workflow.url, "dor/objects/#{pid}/workflows")
    end

    # Called by rubydora. This lets us customize the mime-type
    def self.default_attributes
      super.merge(mimeType: 'application/xml')
    end
  end
end
