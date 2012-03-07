require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'dor/datastreams/events_ds'
require 'equivalent-xml'

describe Dor::EventsDS do
  
  before(:each) do      
    @dsxml =<<-EOF
      <events>
        <event type="eems" who="sunetid:jwible" when="2011-02-23T12:41:09-08:00">Request created by Joe Wible</event>
        <event type="eems" who="sunetid:jwible" when="2011-02-23T12:42:19-08:00">File uploaded by Joe Wible</event>
        <event type="embargo" who="sunetid:hfrost" when="2011-06-03T09:12:32-08:00">Embargo reset from 2012-03-01 to 2012-06-01 by Hannah Frost</event>
        <event type="embargo" who="application:embargo" when="2012-06-20T00:11:10-08:00">Embargo released</event>
      </events>
    EOF
  end
  
  context "Marshalling to and from a Fedora Datastream" do
    
    it "creates itself from xml" do
      ds = Dor::EventsDS.from_xml(@dsxml)
      ds.find_by_terms(:event).size.should == 4
    end
        
    it "creates a simple default with #new" do
      xml = "<events/>"
      
      ds = Dor::EventsDS.new nil, 'events'
      ds.to_xml.should be_equivalent_to(xml)
    end    
  end
  
  describe "#add_event" do
    it "appends a new event element to the set of events" do
      ds = Dor::EventsDS.new nil, 'events'
      ds.add_event "embargo", "application:etd-robot", "Embargo released"
      
      events = ds.find_by_terms(:event)
      events.size.should == 1
      events.first['type'].should == 'embargo'
      events.first['who'].should == 'application:etd-robot'
      Time.parse(events.first['when']).should > Time.now - 10000
      events.first.content.should == 'Embargo released'
    end
    
    it "keeps events in sorted order" do
      ds = Dor::EventsDS.from_xml(@dsxml)
      ds.add_event "embargo", "application:etd-robot", "Embargo go bye-bye"
      
      ds.find_by_terms(:event).last.content.should == 'Embargo go bye-bye'
    end
    
    it "markes the datastream dirty" do
      ds = Dor::EventsDS.from_xml(@dsxml)
      ds.add_event "embargo", "application:etd-robot", "Embargo go bye-bye"
      ds.should be_dirty
    end
  end
  
  describe "#find_events_by_type" do
                
    it "returns a block with who, timestamp, and message" do
      ds = Dor::EventsDS.from_xml(@dsxml)
      ds.add_event "publish", "application:common-accessioning-robot", "Released to the world"
      
      ds.find_events_by_type("publish") do |who, timestamp, message|
        who.should == "application:common-accessioning-robot"
        timestamp.should > Time.now - 10000
        message.should == "Released to the world"
      end
      
      count = 0
      ds.find_events_by_type("embargo") {|w, t, m| count += 1}
      count.should == 2
    end
  end
  
  describe "#each_event" do
    it "returns a block with type, who, timestamp, and message for all events" do
      ds = Dor::EventsDS.from_xml(@dsxml)
      all_types = []
      all_whos = []
      count = 0
      ds.each_event do |type, who, timestamp, message|
        all_types << type
        all_whos << who
        timestamp.class.should be Time
        message.class.should be String
        count += 1
      end
      
      all_types.should == ['eems', 'eems', 'embargo', 'embargo']
      all_whos.should == ['sunetid:jwible', 'sunetid:jwible', 'sunetid:hfrost', 'application:embargo']
      count.should be 4
    end
  end
  
end