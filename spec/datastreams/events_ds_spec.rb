# frozen_string_literal: true

require 'spec_helper'

describe Dor::EventsDS do
  before(:each) do
    @dsxml = <<-EOF
      <events>
        <event type="eems" who="sunetid:jwible" when="2011-02-23T12:41:09-08:00">Request created by Joe Wible</event>
        <event type="eems" who="sunetid:jwible" when="2011-02-23T12:42:19-08:00">File uploaded by Joe Wible</event>
        <event type="embargo" who="sunetid:hfrost" when="2011-06-03T09:12:32-08:00">Embargo reset from 2012-03-01 to 2012-06-01 by Hannah Frost</event>
        <event type="embargo" who="application:embargo" when="2012-06-20T00:11:10-08:00">Embargo released</event>
      </events>
    EOF
  end

  context 'Marshalling to and from a Fedora Datastream' do
    it 'creates itself from xml' do
      ds = Dor::EventsDS.from_xml(@dsxml)
      expect(ds.find_by_terms(:event).size).to eq(4)
    end
    it 'creates a simple default with #new' do
      ds = Dor::EventsDS.new nil, 'events'
      expect(ds.to_xml).to be_equivalent_to('<events/>')
    end
  end

  describe '#add_event' do
    it 'appends a new event element to the set of events' do
      ds = Dor::EventsDS.new nil, 'events'
      ds.add_event 'embargo', 'application:etd-robot', 'Embargo released'

      events = ds.find_by_terms(:event)
      expect(events.size).to eq(1)
      expect(events.first['type']).to eq('embargo')
      expect(events.first['who']).to eq('application:etd-robot')
      expect(Time.parse(events.first['when'])).to be > Time.now.utc - 10_000
      expect(events.first.content).to eq('Embargo released')
    end

    it 'keeps events in sorted order' do
      ds = Dor::EventsDS.from_xml(@dsxml)
      ds.add_event 'embargo', 'application:etd-robot', 'Embargo go bye-bye'
      expect(ds.find_by_terms(:event).last.content).to eq('Embargo go bye-bye')
    end

    it 'markes the datastream changed' do
      ds = Dor::EventsDS.from_xml(@dsxml)
      ds.add_event 'embargo', 'application:etd-robot', 'Embargo go bye-bye'
      expect(ds).to be_changed
    end
  end

  describe '#find_events_by_type' do
    it 'returns a block with who, timestamp, and message' do
      ds = Dor::EventsDS.from_xml(@dsxml)
      ds.add_event 'publish', 'application:common-accessioning-robot', 'Released to the world'

      ds.find_events_by_type('publish') do |who, timestamp, message|
        expect(who).to eq('application:common-accessioning-robot')
        expect(timestamp).to be > Time.now.utc - 10_000
        expect(message).to eq('Released to the world')
      end

      count = 0
      ds.find_events_by_type('embargo') { count += 1 }
      expect(count).to eq(2)
    end
  end

  describe '#each_event' do
    it 'returns a block with type, who, timestamp, and message for all events' do
      ds = Dor::EventsDS.from_xml(@dsxml)
      all_types = []
      all_whos = []
      count = 0
      ds.each_event do |type, who, timestamp, message|
        all_types << type
        all_whos << who
        expect(timestamp.class).to be Time
        expect(message.class).to be String
        count += 1
      end

      expect(all_types).to eq(%w(eems eems embargo embargo))
      expect(all_whos).to eq(['sunetid:jwible', 'sunetid:jwible', 'sunetid:hfrost', 'application:embargo'])
      expect(count).to be 4
    end
  end
end
