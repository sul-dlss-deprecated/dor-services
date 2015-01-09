require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'
require 'dor/datastreams/embargo_metadata_ds'

describe Dor::EmbargoMetadataDS do
  context "Marshalling to and from a Fedora Datastream" do
    let(:dsxml) { <<-EOF
          <embargoMetadata>
          	<status>embargoed</status>
          	<releaseDate>2011-10-12T15:47:52-07:00</releaseDate>
          	<twentyPctVisibilityStatus>released</twentyPctVisibilityStatus>
          	<twentyPctVisibilityReleaseDate>2016-10-12T15:47:52-07:00</twentyPctVisibilityReleaseDate>
          	<releaseAccess>
          		<access type="discover">
          			<machine>
          				<world />
          			</machine>
          		</access>
          		<access type="read">
          			<machine>
          				<world />
          			</machine>
          		</access>
          	</releaseAccess>
          </embargoMetadata>
    EOF
    }

    it "creates itself from xml" do
      ds = Dor::EmbargoMetadataDS.from_xml(dsxml)
      expect(ds.term_values(:status)).to eq(["embargoed"])
      expect(ds.term_values(:release_date)).to eq(["2011-10-12T15:47:52-07:00"])
      expect(ds.term_values(:twenty_pct_status)).to eq(["released"])
      expect(ds.term_values(:twenty_pct_release_date)).to eq(["2016-10-12T15:47:52-07:00"])
      expect(ds.find_by_terms(:release_access).class).to eq(Nokogiri::XML::NodeSet)
    end

    it "creates a simple default with #new" do
      emb_xml = <<-EOF
      <embargoMetadata>
      	<status/>
      	<releaseDate/>
      	<releaseAccess/>
      	<twentyPctVisibilityStatus/>
        <twentyPctVisibilityReleaseDate/>
      </embargoMetadata>
      EOF

      ds = Dor::EmbargoMetadataDS.new nil, 'embargoMetadata'
      expect(ds.to_xml).to be_equivalent_to(emb_xml)
    end

    it "should solrize correctly" do
      ds = Dor::EmbargoMetadataDS.from_xml(dsxml)
      release_date_field = Solrizer.solr_name('embargo_release_date', :searchable)
      expect(ds.to_solr[release_date_field]).to include('2011-10-12T22:47:52Z')
      expect(ds.to_solr[Solrizer.solr_name('twenty_pct_visibility_release_date', :searchable)]).to include('2016-10-12T22:47:52Z')
    end
  end

  describe "#status" do

    ds = Dor::EmbargoMetadataDS.new nil, 'embargoMetadata'
    ds.status = "released"

    it "= sets status" do
      expect(ds.term_values(:status)).to eq(["released"])
    end

    it "= marks the datastream as changed" do
      expect(ds).to be_changed
    end

    it "gets the current value of status" do
      expect(ds.status).to eq("released")
    end
  end

  describe "#release_date" do

    ds = Dor::EmbargoMetadataDS.new nil, 'embargoMetadata'
    t = Time.now - 10
    ds.release_date = t

    it "= sets releaseDate from a Time object as the start of day, UTC" do
      rd = Time.parse(ds.term_values(:release_date).first)
      expect(rd).to eq(t.beginning_of_day.utc)
    end

    it "= marks the datastram as changed" do
      expect(ds).to be_changed
    end

    it "gets the current value of releaseDate as a Time object" do
      rd = ds.release_date
      expect(rd.class).to eq(Time)
      expect(rd).to be < Time.now
    end
  end

  describe "releaseAccess manipulation" do

    ds = Dor::EmbargoMetadataDS.new nil, 'embargoMetadata'
    nd = ds.release_access_node

    it "#release_access_node returns a Nokogiri::XML::Element" do
      expect(nd.class).to eq(Nokogiri::XML::Element)
      expect(nd.name).to eq('releaseAccess')
    end

    it "#release_access_node= sets the embargoAccess node from a Nokogiri::XML::Node" do
      # delete old releaseAcess element and replace with this one
      embargo_xml = <<-EOXML
      <releaseAccess>
    		<access type="discover">
    			<machine>
    				<world />
    			</machine>
    		</access>
    		<access type="read">
    			<machine>
    				<world/>
    			</machine>
    		</access>
    	</embargoAccess>
      EOXML

      ds.release_access_node = Nokogiri::XML(embargo_xml)
      embargo = ds.find_by_terms(:release_access)
      expect(embargo.at_xpath("//releaseAccess/access[@type='read']/machine/world")).to be
      expect(ds).to be_changed
    end

    it "rejects Documents that do not have a root node of releaseAccess" do
      embargo_xml = "<incorrect/>"
      expect { ds.release_access_node = Nokogiri::XML(embargo_xml) }.to raise_error
    end
  end

  describe "Solr indexing" do
    pending
  end
end
