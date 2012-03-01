require 'active_fedora'

class EventsDS < ActiveFedora::NokogiriDatastream
  before_create :ensure_non_versionable
  
  set_terminology do |t|
    t.root(:path => "events")
    t.event do
      t.who :path => { :attribute => "who" }, :index_as => [:displayable, :not_searchable]
      t.type_ :path => { :attribute => "type" }, :index_as => [:displayable, :not_searchable]
      t.when :path => { :attribute => "when" }, :index_as => [:displayable, :not_searchable], :data_type => :date
      t.message :path => "text()", :index_as => [:displayable, :not_searchable]
    end
  end
  
  # Default EventsDS xml 
  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.events
    end
    return builder.doc
  end
  
  def ensure_non_versionable
    self.versionable = "false"
  end
  
  # Adds an event to the datastream
  # @param [String] type a tag used to group events together. Sets the type attribute for the event
  # @param [String] who who is responsible for this event. Sets the who attribute for the event
  # @param [String] message what happened. Sets the content of the event with this message
  def add_event(type, who, message)
    ev = ng_xml.create_element "event", message, 
      :type => type, :who => who, :when => Time.now.xmlschema
    ng_xml.root.add_child(ev)
    self.dirty = true
  end
  
  # Finds events with the desired type attribute
  # @param [String] tag events where type == tag will be returned
  # @yield [who, timestamp, message] The values of the current event
  # @yieldparam [String] who thing responsible for creating the event. Value of the 'who' attribute
  # @yieldparam [Time] timestamp when this event was logged.  Value of the 'when' attribute
  # @yieldparam [String] message what happened. Content of the event node
  def find_events_by_type(tag, &block)
    find_by_terms(:event).xpath("//event[@type='#{tag}']").each do |node|
      block.call(node['who'], Time.parse(node['when']), node.content)
    end
  end
  
  # Returns all the events in the datastream
  # @yield [type, who, timestamp, message] The values of the current event
  # @yieldparam [String] type tag for this particular event.  Value of the 'type' attribute
  # @yieldparam [String] who thing responsible for creating the event. Value of the 'who' attribute
  # @yieldparam [Time] timestamp when this event was logged.  Value of the 'when' attribute
  # @yieldparam [String] message what happened. Content of the event node
  def each_event(&block)
    find_by_terms(:event).each do |node|
      block.call(node['type'], node['who'], Time.parse(node['when']), node.content)
    end
  end
  
end