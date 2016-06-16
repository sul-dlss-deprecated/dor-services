require 'spec_helper'

class EmbargoedItem < ActiveFedora::Base
  include Dor::Embargoable
end

describe Dor::Embargoable do
  let(:embargo_release_date) { Time.now.utc - 100000 }
  let(:release_access) { <<-EOXML
    <releaseAccess>
      <access type="read">
        <machine>
          <world/>
        </machine>
      </access>
      <access type="read">
        <file id="restricted.doc"/>
        <machine>
          <group>stanford</group>
        </machine>
      </access>
    </releaseAccess>
    EOXML
  }
  let(:rights_xml) { <<-EOXML
    <rightsMetadata objectId="druid:rt923jk342">
      <copyright>
        <human>(c) Copyright [conferral year] by [student name]</human>
      </copyright>
      <access type="discover">
        <machine>
          <world />
        </machine>
      </access>
      <access type="read">
        <machine>
          <group>stanford</group>
          <embargoReleaseDate>#{embargo_release_date.iso8601}</embargoReleaseDate>
        </machine>
      </access>
      <use>
        <machine type="creativeCommons" type="code">value</machine>
      </use>
    </rightsMetadata>
    EOXML
  }

  before :each do
    stub_config
    allow(ActiveFedora).to receive(:fedora).and_return(double('frepo').as_null_object)
  end
  after :each do
    unstub_config
  end

  describe '#release_embargo' do
    let(:embargo_ds) {
      eds = Dor::EmbargoMetadataDS.new
      eds.status = 'embargoed'
      eds.release_date = embargo_release_date
      eds.release_access_node = Nokogiri::XML(release_access) {|config| config.default_xml.noblanks}
      eds
    }
    let!(:embargo_item) {
      embargo_item = EmbargoedItem.new
      embargo_item.datastreams['embargoMetadata'] = embargo_ds
      rds = Dor::RightsMetadataDS.new
      rds.content = Nokogiri::XML(rights_xml) {|config| config.default_xml.noblanks}.to_s
      embargo_item.datastreams['rightsMetadata'] = rds
      expect(embargo_item.rightsMetadata).to receive(:content=)
      embargo_item.release_embargo('application:embargo-release')
      embargo_item
    }

    it 'sets the embargo status to released' do
      expect(embargo_ds.status).to eq('released')
    end

    context 'rightsMetadata modifications' do
      it 'deletes embargoReleaseDate' do
        rights = embargo_item.datastreams['rightsMetadata'].ng_xml
        expect(rights.at_xpath('//embargoReleaseDate')).to be_nil
      end
      it 'replaces/adds access nodes with nodes from embargoMetadata/releaseAccess' do
        rights = embargo_item.datastreams['rightsMetadata'].ng_xml
        expect(rights.xpath("//rightsMetadata/access[@type='read']").size).to eq(2)
        expect(rights.xpath("//rightsMetadata/access[@type='discover']").size).to eq(1)
        expect(rights.xpath("//rightsMetadata/access[@type='read']/machine/world").size).to eq(1)
        expect(rights.at_xpath("//rightsMetadata/access[@type='read' and not(file)]/machine/group")).to be_nil
      end
      it "handles more than one <access type='read'> node in <releaseAccess>, even those with <file> nodes" do
        rights = embargo_item.datastreams['rightsMetadata'].ng_xml
        expect(rights.xpath("//rightsMetadata/access[@type='read']/file").size).to eq(1)
      end
      it 'marks the datastream as changed' do
        expect(embargo_item.datastreams['rightsMetadata']).to be_changed
      end
    end

    it "writes 'embargo released' to event history" do
      events = embargo_item.datastreams['events']
      events.find_events_by_type('embargo') do |who, timestamp, message|
        expect(who).to eq 'application:embargo-release'
        expect(message).to eq 'Embargo released'
      end
    end
  end

  describe '#release_20_pct_vis_embargo' do
    let(:embargo_ds) {
      eds = Dor::EmbargoMetadataDS.new
      eds.status = 'embargoed'
      eds.release_date = embargo_release_date
      eds.release_access_node = Nokogiri::XML(release_access) {|config| config.default_xml.noblanks}
      eds
    }
    let!(:embargo_item) {
      embargo_item = EmbargoedItem.new
      embargo_item.datastreams['embargoMetadata'] = embargo_ds
      embargo_item.datastreams['rightsMetadata'].ng_xml = Nokogiri::XML(rights_xml) {|config| config.default_xml.noblanks}
      expect(embargo_item.rightsMetadata).to receive(:content=)
      embargo_item.release_20_pct_vis_embargo('application:embargo-release')
      embargo_item
    }

    it 'sets the embargo status to released' do
      expect(embargo_ds.twenty_pct_status).to eq 'released'
    end

    context 'rightsMetadata modifications' do
      it 'replaces stanford group read access to world read access' do
        rights = embargo_item.datastreams['rightsMetadata'].ng_xml
        expect(rights.xpath("//rightsMetadata/access[@type='read']"              ).size).to eq 1
        expect(rights.xpath("//rightsMetadata/access[@type='discover']"          ).size).to eq 1
        expect(rights.xpath("//rightsMetadata/access[@type='read']/machine/world").size).to eq 1
      end
      it 'marks the datastream as content changed' do
        expect(embargo_item.datastreams['rightsMetadata']).to be_content_changed
      end
    end

    it "writes 'embargo released' to event history" do
      events = embargo_item.datastreams['events']
      events.find_events_by_type('embargo') do |who, timestamp, message|
        expect(who).to eq('application:embargo-release')
        expect(message).to eq('20% Visibility Embargo released')
      end
    end
  end

  describe '#update_embargo' do
    let(:embargo_item) {
      embargo_item = EmbargoedItem.new
      eds = embargo_item.datastreams['embargoMetadata']
      eds.status = 'embargoed'
      eds.release_date = embargo_release_date
      eds.release_access_node = Nokogiri::XML(release_access) {|config| config.default_xml.noblanks}
      allow_any_instance_of(ActiveFedora::OmDatastream).to receive(:save).and_return(true)
      embargo_item.datastreams['rightsMetadata'].ng_xml = Nokogiri::XML(rights_xml) {|config| config.default_xml.noblanks}
      embargo_item
    }

    it 'updates embargo date' do
      old_embargo_date = embargo_item.embargoMetadata.release_date
      embargo_item.update_embargo(Time.now.utc + 1.month)
      expect(embargo_item.embargoMetadata.release_date).not_to eq old_embargo_date
    end
    it 'updates embargo and rights datastreams with content= ' do
      expect(embargo_item.embargoMetadata).to receive(:content=)
      expect(embargo_item.rightsMetadata).to receive(:content=)
      embargo_item.update_embargo(Time.now.utc + 1.month)
    end
    it "raises ArgumentError if the item isn't embargoed" do
      embargo_item.release_embargo('application:embargo-release')
      expect{embargo_item.update_embargo(Time.now.utc + 1.month)}.to raise_error(ArgumentError)
    end
    it 'raises ArgumentError if the new date is in the past' do
      expect{embargo_item.update_embargo(1.month.ago)}.to raise_error(ArgumentError)
    end
  end
end
