require 'spec_helper'

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


  let(:ds) {
    d = Dor::VersionMetadataDS.new double(:pid => 'druid:ab123cd4567', :new? => false, :repository => double()), 'versionMetadata'
    d.stub(:new?).and_return(false)
    d.stub(:inline?).and_return true
    d.stub(:datastream_content).and_return(first_xml)
    d
  }


  describe "Marshalling to and from a Fedora Datastream" do

    it "creates itself from xml" do
      ds = Dor::VersionMetadataDS.from_xml(dsxml)
      ds.find_by_terms(:version).size.should == 3
    end

    it "creates a simple default with #new" do
      ds = Dor::VersionMetadataDS.new nil, 'versionMetadata'
      ds.stub(:pid).and_return('druid:ab123cd4567')
      ds.to_xml.should be_equivalent_to(first_xml)
    end
  end

  describe "#increment_version" do

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

  describe 'current_tag' do
    it 'returns the tag of the lastest version' do
      ds = Dor::VersionMetadataDS.from_xml(dsxml)
      ds.current_tag.should == '2.1.0'
    end
    it 'should work if there is no tag' do
      no_tag='<versionMetadata><version versionId="3">
      <description>Some text</description>
      </version>
      </versionMetadata>'
      ds = Dor::VersionMetadataDS.from_xml(no_tag)
      ds.current_tag.should == ''

    end
  end

  describe 'current_description' do
    it 'returns the description of the latest version' do
      ds = Dor::VersionMetadataDS.from_xml(dsxml)
      ds.current_description.should == 'Fixed title typo'
    end
    it 'should work ok if there isnt a description' do
      no_desc='<versionMetadata><version versionId="3" tag="2.1.0">
      </version>
      </versionMetadata>'
      ds = Dor::VersionMetadataDS.from_xml(no_desc)
      ds.current_description.should == ''
    end
  end

  describe 'tag_for_version' do
    it 'should fetch the tag for a version' do
      ds = Dor::VersionMetadataDS.from_xml(dsxml)
      ds.tag_for_version('2').should == '2.0.0'
    end
  end

  describe 'description_for_version' do
    it 'should fetch the description for a version' do
      ds = Dor::VersionMetadataDS.from_xml(dsxml)
      ds.description_for_version('3').should == 'Fixed title typo'
    end
    it 'should return empty string if the description doesnt exist' do
      no_desc='<versionMetadata>
      <version versionId="3" tag="2.1.0">
      </version>
      </versionMetadata>'
      ds = Dor::VersionMetadataDS.from_xml(no_desc)
      ds.description_for_version('3').should == ''
    end
  end

  describe 'sync_then_increment_version' do

    let(:five_versions_xml) {  <<-XML
      <versionMetadata objectId="druid:ab123cd4567">
        <version versionId="1" tag="1.0.0">
          <description>Initial Version</description>
        </version>
        <version versionId="2" tag="1.1.0">
          <description>minor update</description>
        </version>
        <version versionId="3" tag="2.1.0">
          <description>minor update</description>
        </version>
        <version versionId="4" tag="3.1.0">
          <description>minor update</description>
        </version>
        <version versionId="5" tag="4.1.0">
          <description>minor update</description>
        </version>
      </versionMetadata>
      XML
    }

    it 'removes any version tags greater than the last known version, then creates a new version tag' do
      ds = Dor::VersionMetadataDS.from_xml(five_versions_xml)
      allow(ds).to receive(:pid).and_return('druid:ab123cd4567')

      ds.sync_then_increment_version(2, :description => "Down to third version", :significance => :major)

      expect(ds.to_xml).to be_equivalent_to( <<-XML
      <versionMetadata objectId="druid:ab123cd4567">
        <version versionId="1" tag="1.0.0">
          <description>Initial Version</description>
        </version>
        <version versionId="2" tag="1.1.0">
          <description>minor update</description>
        </version>
        <version versionId="3" tag="2.0.0">
          <description>Down to third version</description>
        </version>
      </versionMetadata>
      XML
      )
    end

    it 'increments the version if the requested version is equal to the current version' do
      ds = Dor::VersionMetadataDS.from_xml(five_versions_xml)
      allow(ds).to receive(:pid).and_return('druid:ab123cd4567')

      ds.sync_then_increment_version(5, :description => "Up to 6", :significance => :major)

      expect(ds.to_xml).to be_equivalent_to( <<-XML
      <versionMetadata objectId="druid:ab123cd4567">
        <version versionId="1" tag="1.0.0">
          <description>Initial Version</description>
        </version>
        <version versionId="2" tag="1.1.0">
          <description>minor update</description>
        </version>
        <version versionId="3" tag="2.1.0">
          <description>minor update</description>
        </version>
        <version versionId="4" tag="3.1.0">
          <description>minor update</description>
        </version>
        <version versionId="5" tag="4.1.0">
          <description>minor update</description>
        </version>
        <version versionId="6" tag="5.0.0">
          <description>Up to 6</description>
        </version>
      </versionMetadata>
      XML
      )
    end

    it 'performs synch and increment without any options' do
      ds = Dor::VersionMetadataDS.from_xml(five_versions_xml)
      allow(ds).to receive(:pid).and_return('druid:ab123cd4567')

      ds.sync_then_increment_version(3)

      expect(ds.current_version_id).to eq "4"
    end

    it 'raises an Exception if requested version is greater than current version' do
      ds = Dor::VersionMetadataDS.from_xml(five_versions_xml)
      allow(ds).to receive(:pid).and_return('druid:ab123cd4567')

      expect{ ds.sync_then_increment_version(6) }.to raise_error(Dor::Exception, "Cannot sync to a version greater than current: 5, requested 6")
    end
  end

end
