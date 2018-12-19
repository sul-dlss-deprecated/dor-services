# frozen_string_literal: true

module Dor
  module Eventable
    extend Deprecation
    extend ActiveSupport::Concern
    self.deprecation_horizon = 'dor-services version 7.0.0'

    included do
      has_metadata name: 'events', type: Dor::EventsDS, label: 'Events'
    end

    def add_event(*args)
      datastreams['events'].add_event *args
    end
    deprecation_deprecate add_event: 'call item.events.add_event instead.'
  end
end
