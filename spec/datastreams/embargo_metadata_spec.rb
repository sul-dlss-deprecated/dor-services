require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'
require 'equivalent-xml'
require 'datastreams/embargo_metadata_ds'

describe EmbargoMetadataDS do
  context "Marshalling to and from a Fedora Datastream" do
    before(:each) do      
      @dsxml =<<-EOF
            <embargoMetadata>
            	<status>embargoed</status>
            	<releaseDate>2011-10-12T15:47:52-07:00</releaseDate>
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
    end
    
    it "creates itself from xml" do
      ds = EmbargoMetadataDS.from_xml(@dsxml)
      ds.term_values(:status).should == ["embargoed"]
      ds.term_values(:release_date).should == ["2011-10-12T15:47:52-07:00"]
      ds.find_by_terms(:release_access).class.should == Nokogiri::XML::NodeSet
    end
        
    it "creates a simple default with #new" do
      emb_xml = <<-EOF
      <embargoMetadata>
      	<status/>
      	<releaseDate/>
      	<releaseAccess/>
      </embargoMetadata>
      EOF
      
      ds = EmbargoMetadataDS.new      
      ds.to_xml.should be_equivalent_to(emb_xml)
    end    
  end
  
  describe "#status" do
    
    ds = EmbargoMetadataDS.new
    ds.status = "released"
    
    it "= sets status" do
      ds.term_values(:status).should == ["released"]
    end
    
    it "gets the current value of status" do
      ds.status.should == "released"
    end
  end
  
  describe "#release_date" do
    
    ds = EmbargoMetadataDS.new
    ds.release_date = Time.now - 10
    
    it "= sets releaseDate from a Time object" do
      rd = Time.parse(ds.term_values(:release_date).first)
      rd.should < Time.now
    end
    
    it "gets the current value of releaseDate as a Time object" do
      rd = ds.release_date
      rd.class.should == Time
      rd.should < Time.now
    end
  end

  describe "releaseAccess manipulation" do
    
    ds = EmbargoMetadataDS.new
    nd = ds.release_access_node

    it "#release_access_node returns a Nokogiri::XML::Element" do
      nd.class.should == Nokogiri::XML::Element
      nd.name.should == 'releaseAccess'
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
      embargo.at_xpath("//releaseAccess/access[@type='read']/machine/world").should be
    end
    
    it "rejects Documents that do not have a root node of releaseAccess" do
      embargo_xml = "<incorrect/>"
      lambda { ds.release_access_node = Nokogiri::XML(embargo_xml) }.should raise_error
    end
  end
end