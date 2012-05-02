module Dor
  module Eventable
    extend ActiveSupport::Concern
    included do
      has_metadata :name => 'events', :type => Dor::EventsDS, :label => 'Events'
    end
    
    def add_event *args
      self.datastreams['events'].add_event *args
    end
  end
end