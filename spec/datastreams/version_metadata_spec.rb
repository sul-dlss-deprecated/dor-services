# frozen_string_literal: true

require 'spec_helper'

describe Dor::VersionMetadataDS do
  let(:dsxml) do
    <<-XML
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
  end

  let(:first_xml) do
    <<-XML
    <versionMetadata>
    <version versionId="1" tag="1.0.0">
    <description>Initial Version</description>
    </version>
    </versionMetadata>
    XML
  end

  let(:ds) do
    d = described_class.new double(pid: 'druid:ab123cd4567', new?: false, repository: double), 'versionMetadata'
    allow(d).to receive(:new?).and_return(false)
    allow(d).to receive(:inline?).and_return true
    allow(d).to receive(:datastream_content).and_return(first_xml)
    d
  end

  describe 'Marshalling to and from a Fedora Datastream' do
    it 'creates itself from xml' do
      ds = described_class.from_xml(dsxml)
      expect(ds.find_by_terms(:version).size).to eq(3)
    end

    it 'creates a simple default with #new' do
      ds = described_class.new nil, 'versionMetadata'
      allow(ds).to receive(:pid).and_return('druid:ab123cd4567')
      expect(ds.to_xml).to be_equivalent_to(first_xml)
    end
  end

  describe '#increment_version' do
    it 'appends a new version block with an incremented versionId and converts significance to a tag' do
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
      ds.increment_version('minor update', :minor)
      expect(ds.to_xml).to be_equivalent_to(v2)
    end

    it 'appends a new version block with an incremented versionId without passing in significance' do
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

      ds.increment_version('Next Version')
      expect(ds.to_xml).to be_equivalent_to(v2)
    end
  end

  describe '#update_current_version' do
    let(:first_xml) do
      <<-XML
      <versionMetadata objectId="druid:ab123cd4567">
      <version versionId="1" tag="1.0.0">
      <description>Initial Version</description>
      </version>
      </versionMetadata>
      XML
    end

    it 'updates the current version with the passed in options' do
      ds.increment_version('minor update') # no tag
      ds.update_current_version description: 'new text', significance: :major
      expect(ds.to_xml).to be_equivalent_to(<<-XML
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

    it 'changes the previous value of tag with the new passed in version' do
      ds.increment_version('major update', :major) # Setting tag to 2.0.0
      ds.update_current_version description: 'now minor update', significance: :minor
      expect(ds.to_xml).to be_equivalent_to(<<-XML
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

    it 'does not do anything if there is only 1 version' do
      ds.update_current_version description: 'now minor update', significance: :minor # should be ignored
      expect(ds.to_xml).to be_equivalent_to(<<-XML
      <versionMetadata objectId="druid:ab123cd4567">
      <version versionId="1" tag="1.0.0">
      <description>Initial Version</description>
      </version>
      </versionMetadata>
      XML
                                           )
    end
  end

  describe '#current_version_id' do
    it 'finds the largest versionId within the versionMetadataDS' do
      ds = described_class.from_xml(dsxml)
      expect(ds.current_version_id).to eq('3')
    end
  end

  describe 'current_tag' do
    it 'returns the tag of the lastest version' do
      ds = described_class.from_xml(dsxml)
      expect(ds.current_tag).to eq('2.1.0')
    end
    it 'works if there is no tag' do
      no_tag = '<versionMetadata><version versionId="3">
      <description>Some text</description>
      </version>
      </versionMetadata>'
      ds = described_class.from_xml(no_tag)
      expect(ds.current_tag).to eq('')
    end
  end

  describe 'current_description' do
    it 'returns the description of the latest version' do
      ds = described_class.from_xml(dsxml)
      expect(ds.current_description).to eq('Fixed title typo')
    end
    it 'works ok if there isnt a description' do
      no_desc = '<versionMetadata><version versionId="3" tag="2.1.0">
      </version>
      </versionMetadata>'
      ds = described_class.from_xml(no_desc)
      expect(ds.current_description).to eq('')
    end
  end

  describe 'tag_for_version' do
    it 'fetches the tag for a version' do
      ds = described_class.from_xml(dsxml)
      expect(ds.tag_for_version('2')).to eq('2.0.0')
    end
  end

  describe 'description_for_version' do
    it 'fetches the description for a version' do
      ds = described_class.from_xml(dsxml)
      expect(ds.description_for_version('3')).to eq('Fixed title typo')
    end
    it 'returns empty string if the description doesnt exist' do
      no_desc = '<versionMetadata>
      <version versionId="3" tag="2.1.0">
      </version>
      </versionMetadata>'
      ds = described_class.from_xml(no_desc)
      expect(ds.description_for_version('3')).to eq('')
    end
  end

  describe 'sync_then_increment_version' do
    let(:five_versions_xml) do
      <<-XML
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
    end

    it 'removes any version tags greater than the last known version, then creates a new version tag' do
      ds = described_class.from_xml(five_versions_xml)
      allow(ds).to receive(:pid).and_return('druid:ab123cd4567')

      ds.sync_then_increment_version(2, description: 'Down to third version', significance: :major)

      expect(ds.to_xml).to be_equivalent_to(<<-XML
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
      ds = described_class.from_xml(five_versions_xml)
      allow(ds).to receive(:pid).and_return('druid:ab123cd4567')

      ds.sync_then_increment_version(5, description: 'Up to 6', significance: :major)

      expect(ds.to_xml).to be_equivalent_to(<<-XML
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
      ds = described_class.from_xml(five_versions_xml)
      allow(ds).to receive(:pid).and_return('druid:ab123cd4567')

      ds.sync_then_increment_version(3)

      expect(ds.current_version_id).to eq '4'
    end

    it 'raises an Exception if requested version is greater than current version' do
      ds = described_class.from_xml(five_versions_xml)
      allow(ds).to receive(:pid).and_return('druid:ab123cd4567')

      expect { ds.sync_then_increment_version(6) }.to raise_error(Dor::Exception, 'Cannot sync to a version greater than current: 5, requested 6')
    end
  end
end
