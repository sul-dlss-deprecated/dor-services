require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'dor/datastreams/version_metadata_ds'

describe Dor::VersionMetadataDS do
  let(:dsxml)  { <<-XML
    <versionMetadata objectId="druid:ab123cd4567">
      <version versionId="1" tag="1.0.0">
        <description>Initial version</description>
      </version>
      <version versionId="2" tag="2.0.0">
        <description>Replacing main PDF</description>
      </version>
      <version versionId="3" tag="2.1.0">
        <description>Fixed title typo</description>
      </version>
    </versionMetadata>
    XML
  }
  
  let(:first_xml) { <<-XML
      <versionMetadata>
        <version versionId="1" tag="1.0.0">
          <description>Initial Version</description>
        </version>
      </versionMetadata>
    XML
  }
  
  describe "Marshalling to and from a Fedora Datastream" do
    
    it "creates itself from xml" do
      ds = Dor::VersionMetadataDS.from_xml(dsxml)
      ds.find_by_terms(:version).size.should == 3
    end
    
    it "creates a simple default with #new" do
      ds = Dor::VersionMetadataDS.new nil, 'versionMetadata'
      ds.stub!(:pid).and_return('druid:ab123cd4567')
      ds.to_xml.should be_equivalent_to(first_xml)
    end
  end
  
  describe "#increment_version" do
    let(:ds) do
      d = Dor::VersionMetadataDS.new nil, 'versionMetadata'
      d.save
      d.stub!(:pid).and_return('druid:ab123cd4567')
      d
    end
        
    it "appends a new version block with an incremented versionId and converts significance to a tag" do
      v2 = <<-XML
        <versionMetadata objectId="druid:ab123cd4567">
          <version versionId="1" tag="1.0.0">
            <description>Initial Version</description>
          </version>
          <version versionId="2" tag="1.1.0">
            <description>minor update</description>
          </version>
        </versionMetadata>
      XML
      ds.increment_version("minor update", :minor)
      ds.to_xml.should be_equivalent_to(v2)
    end
    
    it "appends a new version block with an incremented versionId without passing in significance" do
      v2 = <<-XML
        <versionMetadata objectId="druid:ab123cd4567">
          <version versionId="1" tag="1.0.0">
            <description>Initial Version</description>
          </version>
          <version versionId="2">
            <description>Next Version</description>
          </version>
        </versionMetadata>
      XML
      
      ds.increment_version("Next Version")
      ds.to_xml.should be_equivalent_to(v2)
    end
  end
  
  describe "#update_current_version" do
    
    let(:first_xml) { <<-XML
        <versionMetadata objectId="druid:ab123cd4567">
          <version versionId="1" tag="1.0.0">
            <description>Initial Version</description>
          </version>
        </versionMetadata>
      XML
    }
    
    let(:ds) {
      d = Dor::VersionMetadataDS.new nil, 'versionMetadata'
      d.stub!(:pid).and_return('druid:ab123cd4567')
      d.save
      d
    }
        
    it "updates the current version with the passed in options" do
      ds.increment_version("minor update") # no tag
      ds.update_current_version :description => 'new text', :significance => :major
      ds.to_xml.should be_equivalent_to( <<-XML
        <versionMetadata objectId="druid:ab123cd4567">
          <version versionId="1" tag="1.0.0">
            <description>Initial Version</description>
          </version>
          <version versionId="2" tag="2.0.0">
            <description>new text</description>
          </version>
        </versionMetadata>
        XML
      )
    end
    
    it "changes the previous value of tag with the new passed in version" do
      ds.increment_version("major update", :major) # Setting tag to 2.0.0
      ds.update_current_version :description => 'now minor update', :significance => :minor
      ds.to_xml.should be_equivalent_to( <<-XML
        <versionMetadata objectId="druid:ab123cd4567">
          <version versionId="1" tag="1.0.0">
            <description>Initial Version</description>
          </version>
          <version versionId="2" tag="1.1.0">
            <description>now minor update</description>
          </version>
        </versionMetadata>
        XML
      )
    end
    
    it "does not do anything if there is only 1 version" do
      ds.update_current_version :description => 'now minor update', :significance => :minor #should be ignored
      ds.to_xml.should be_equivalent_to( <<-XML
        <versionMetadata objectId="druid:ab123cd4567">
          <version versionId="1" tag="1.0.0">
            <description>Initial Version</description>
          </version>
        </versionMetadata>
      XML
      )
    end
  end
  
  describe "#current_version_id" do
    it "finds the largest versionId within the versionMetadataDS" do
      ds = Dor::VersionMetadataDS.from_xml(dsxml)
      ds.current_version_id.should == '3'
    end
  end
  
end