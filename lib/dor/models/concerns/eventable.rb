# frozen_string_literal: true

module Dor
  module Eventable
    extend ActiveSupport::Concern
    included do
      has_metadata name: 'events', type: Dor::EventsDS, label: 'Events'
    end

    def add_event(*args)
      datastreams['events'].add_event *args
    end
  end
end
