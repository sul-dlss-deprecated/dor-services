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
    t = Time.now - 10
    ds.release_date = t
    
    it "= sets releaseDate from a Time object as the start of day, UTC" do
      rd = Time.parse(ds.term_values(:release_date).first)
      rd.should == t.beginning_of_day.utc
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
  
  describe "Solr indexing" do
    
    # <add>
    #   <doc>
    #     ...
    #     <field name="embargo_release_date">2010-03-13T15:26:37Z/DAY</field>
    #     <field name="embargo_status_field">embargoed</field>
    #   </doc>
    # </add>
    it "the gsearch stylesheet stores embargo status and release date in the solr document" do
      foxml = <<-EOXML
      <foxml:digitalObject VERSION="1.1" PID="changeme:99"
      xmlns:foxml="info:fedora/fedora-system:def/foxml#"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="info:fedora/fedora-system:def/foxml# http://www.fedora.info/definitions/1/0/foxml1-1.xsd">
      <foxml:objectProperties>
      <foxml:property NAME="info:fedora/fedora-system:def/model#state" VALUE="Active"/>
      <foxml:property NAME="info:fedora/fedora-system:def/model#ownerId" VALUE="fedoraAdmin"/>
      <foxml:property NAME="info:fedora/fedora-system:def/model#createdDate" VALUE="2011-10-19T21:37:13.246Z"/>
      <foxml:property NAME="info:fedora/fedora-system:def/view#lastModifiedDate" VALUE="2011-10-19T21:37:14.735Z"/>
      </foxml:objectProperties>
      <foxml:datastream ID="embargoMetadata" STATE="A" CONTROL_GROUP="X" VERSIONABLE="false">
      <foxml:datastreamVersion ID="embargoMetadata.0" LABEL="" CREATED="2011-10-19T21:37:13.573Z" MIMETYPE="text/xml" SIZE="122">
      <foxml:xmlContent>
      <embargoMetadata>
        <status>embargoed</status>
        <releaseDate>2012-10-19T00:07:00Z</releaseDate>
        <releaseAccess><blah>does not matter</blah></releaseAccess>
      </embargoMetadata>
      </foxml:xmlContent>
      </foxml:datastreamVersion>
      </foxml:datastream>
      </foxml:digitalObject>
      EOXML
      
      xslt = Nokogiri::XSLT(File.new(File.expand_path(File.dirname(__FILE__)  + '../../../lib/gsearch/demoFoxmlToSolr.xslt')))
      solr_doc = xslt.transform(Nokogiri::XML(foxml))
      solr_doc.at_xpath("//add/doc/field[@name='embargo_status_field']").content.should == "embargoed"
      solr_doc.at_xpath("//add/doc/field[@name='embargo_release_date']").content.should == "2012-10-19T00:07:00Z"
      #puts solr_doc.to_xml
    end
    
    it "embargo fields are not added to the solr doc if there is no embargoMetadata" do
      foxml = <<-EOXML
      <foxml:digitalObject VERSION="1.1" PID="changeme:99"
      xmlns:foxml="info:fedora/fedora-system:def/foxml#"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="info:fedora/fedora-system:def/foxml# http://www.fedora.info/definitions/1/0/foxml1-1.xsd">
      <foxml:objectProperties>
      <foxml:property NAME="info:fedora/fedora-system:def/model#state" VALUE="Active"/>
      <foxml:property NAME="info:fedora/fedora-system:def/model#ownerId" VALUE="fedoraAdmin"/>
      <foxml:property NAME="info:fedora/fedora-system:def/model#createdDate" VALUE="2011-10-19T21:37:13.246Z"/>
      <foxml:property NAME="info:fedora/fedora-system:def/view#lastModifiedDate" VALUE="2011-10-19T21:37:14.735Z"/>
      </foxml:objectProperties>
      <foxml:datastream ID="embargoMetadata" STATE="A" CONTROL_GROUP="X" VERSIONABLE="false">
      <foxml:datastreamVersion ID="embargoMetadata.0" LABEL="" CREATED="2011-10-19T21:37:13.573Z" MIMETYPE="text/xml" SIZE="122">
      <foxml:xmlContent>
      <embargoMetadata>
        <status></status>
        <releaseDate></releaseDate>
        <releaseAccess></releaseAccess>
      </embargoMetadata>
      </foxml:xmlContent>
      </foxml:datastreamVersion>
      </foxml:datastream>
      </foxml:digitalObject>
      EOXML
      
      xslt = Nokogiri::XSLT(File.new(File.expand_path(File.dirname(__FILE__)  + '../../../lib/gsearch/demoFoxmlToSolr.xslt')))
      solr_doc = xslt.transform(Nokogiri::XML(foxml))
      #puts solr_doc.to_xml
      solr_doc.at_xpath("//add/doc/field[@name='embargo_status_field']").should be_nil
      solr_doc.at_xpath("//add/doc/field[@name='embargo_release_date']").should be_nil
    end
    
    it "indexes embargoMetadata from a complete Foxml document" do
      xslt = Nokogiri::XSLT(File.new(File.expand_path(File.dirname(__FILE__)  + '../../../lib/gsearch/demoFoxmlToSolr.xslt')))
      solr_doc = xslt.transform(Nokogiri::XML(File.new(File.expand_path(File.dirname(__FILE__)  + '/../fixtures/foxml_embargo_md.xml'))))
      solr_doc.at_xpath("//add/doc/field[@name='embargo_status_field']").content.should == "embargoed"
    end
    
  end
end