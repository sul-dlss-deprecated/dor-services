require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'equivalent-xml'

class EmbargoedItem < ActiveFedora::Base
  include Dor::Embargoable
end

describe Dor::Embargoable do

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
          <embargoReleaseDate>2011-10-08</embargoReleaseDate>
        </machine>
      </access>
      <use>
        <machine type="creativeCommons" type="code">value</machine>
      </use>
    </rightsMetadata>
    EOXML
  }

  before :all do
    @fixture_dir = fixture_dir = File.join(File.dirname(__FILE__),"../fixtures")
    Dor::Config.push! do
      suri.mint_ids false
      gsearch.url "http://solr.edu/gsearch"
      solrizer.url "http://solr.edu/solrizer"
      fedora.url "http://fedora.edu"
      stacks.local_workspace_root File.join(fixture_dir, "workspace")
    end

    # ActiveFedora::SolrService.register(Dor::Config.gsearch.url)
    # Fedora::Repository.register(Dor::Config.fedora.url)
  end

  after :all do
    Dor::Config.pop!
  end

  before(:each) do
    ActiveFedora.stub!(:fedora).and_return(stub('frepo').as_null_object)
  end

  describe "#release_embargo" do

    before(:each) do
      @embargo_item = EmbargoedItem.new
      @eds = @embargo_item.datastreams['embargoMetadata']
      @eds.status = 'embargoed'
      @eds.release_date = Time.now - 100000
      @eds.release_access_node = Nokogiri::XML(release_access) {|config|config.default_xml.noblanks}

      @embargo_item.datastreams['rightsMetadata'].ng_xml = Nokogiri::XML(rights_xml) {|config|config.default_xml.noblanks}
      @embargo_item.release_embargo('application:embargo-release')
    end

    it "sets the embargo status to released" do
      @eds.status.should == 'released'
    end

    context "rightsMetadata modifications" do

      it "deletes embargoReleaseDate" do
        rights = @embargo_item.datastreams['rightsMetadata'].ng_xml
        rights.at_xpath("//embargoReleaseDate").should be_nil
      end

      it "replaces/adds access nodes with nodes from embargoMetadata/releaseAccess" do
        rights = @embargo_item.datastreams['rightsMetadata'].ng_xml

        rights.xpath("//rightsMetadata/access[@type='read']").size.should == 2
        rights.xpath("//rightsMetadata/access[@type='discover']").size.should == 1
        rights.xpath("//rightsMetadata/access[@type='read']/machine/world").size.should == 1
        rights.at_xpath("//rightsMetadata/access[@type='read' and not(file)]/machine/group").should be_nil
      end

      it "handles more than one <access type='read'> node in <releaseAccess>, even those with <file> nodes" do
        rights = @embargo_item.datastreams['rightsMetadata'].ng_xml
        rights.xpath("//rightsMetadata/access[@type='read']/file").size.should == 1
      end

      it "marks the datastream as changed" do
        @embargo_item.datastreams['rightsMetadata'].should be_changed
      end
    end

    it "writes 'embargo released' to event history" do
      events = @embargo_item.datastreams['events']
      events.find_events_by_type("embargo") do |who, timestamp, message|
        who.should == 'application:embargo-release'
        message.should == "Embargo released"
      end
    end
  end

  describe "#release_20_pct_vis_embargo" do
    let(:embargo_item) {EmbargoedItem.new}
    let(:eds) { embargo_item.datastreams['embargoMetadata'] }

    before(:each) do
      eds.status = 'embargoed'
      eds.release_date = Time.now - 100000
      eds.release_access_node = Nokogiri::XML(release_access) {|config|config.default_xml.noblanks}
      embargo_item.datastreams['rightsMetadata'].ng_xml = Nokogiri::XML(rights_xml) {|config|config.default_xml.noblanks}
      embargo_item.release_20_pct_vis_embargo('application:embargo-release')
    end

    it "sets the embargo status to released" do
      eds.twenty_pct_status.should == 'released'
    end

    context "rightsMetadata modifications" do

      it "replaces stanford group read access to world read access" do
        rights = embargo_item.datastreams['rightsMetadata'].ng_xml

        rights.xpath("//rightsMetadata/access[@type='read']").size.should == 1
        rights.xpath("//rightsMetadata/access[@type='discover']").size.should == 1
        rights.xpath("//rightsMetadata/access[@type='read']/machine/world").size.should == 1
      end

      it "marks the datastream as dirty" do
        embargo_item.datastreams['rightsMetadata'].should be_content_changed
      end
    end

    it "writes 'embargo released' to event history" do
      events = embargo_item.datastreams['events']
      events.find_events_by_type("embargo") do |who, timestamp, message|
        who.should == 'application:embargo-release'
        message.should == "20% Visibility Embargo released"
      end
    end
  end

  describe '#update_embargo' do
    before(:each) do
      @embargo_item = EmbargoedItem.new
      @eds = @embargo_item.datastreams['embargoMetadata']
      @eds.status = 'embargoed'
      @eds.release_date = Time.now - 100000
      @eds.release_access_node = Nokogiri::XML(release_access) {|config|config.default_xml.noblanks}

      ActiveFedora::OmDatastream.any_instance.stub(:save).and_return(true)
      @embargo_item.datastreams['rightsMetadata'].ng_xml = Nokogiri::XML(rights_xml) {|config|config.default_xml.noblanks}
    end

    it 'should update the embargo date' do
      old_embargo_date=@embargo_item.embargoMetadata.release_date
      @embargo_item.update_embargo(Time.now + 1.month)
      (@embargo_item.embargoMetadata.release_date == old_embargo_date).should == false
    end

    it 'should raise an error if the item isnt embargoed' do
      @embargo_item.release_embargo('application:embargo-release')
      lambda{@embargo_item.update_embargo(Time.now + 1.month)}.should raise_error
    end

    it 'should raise an exception if the new date is in the past' do
      lambda{@embargo_item.update_embargo(1.month.ago)}.should raise_error
    end
  end
end
