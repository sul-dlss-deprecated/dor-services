require 'spec_helper'
require 'nokogiri'

describe Dor::IdentityMetadataDS do
  context "Marshalling to and from a Fedora Datastream" do
    before(:each) do
      @dsxml =<<-EOF
        <identityMetadata>
          <objectCreator>DOR</objectCreator>
          <objectId>druid:bb110sm8219</objectId>
          <objectLabel>AMERICQVE | SEPTENTRIONALE</objectLabel>
          <objectType>item</objectType>
          <otherId name="mdtoolkit">bb110sm8219</otherId>
          <otherId name="uuid">b382ee92-da77-11e0-9036-0016034322e4</otherId>
          <sourceId source="sulair">bb110sm8219</sourceId>
          <tag>MDForm : mclaughlin</tag>
          <tag>Project : McLaughlin Maps</tag>
        </identityMetadata>
      EOF

      @dsdoc = Dor::IdentityMetadataDS.from_xml(@dsxml)
    end

    it "creates itself from xml" do
      expect(@dsdoc.term_values(:objectId)).to eq(['druid:bb110sm8219'])
      expect(@dsdoc.term_values(:objectType)).to eq(['item'])
      expect(@dsdoc.term_values(:objectLabel)).to eq(['AMERICQVE | SEPTENTRIONALE'])
      expect(@dsdoc.term_values(:tag)).to match_array(['MDForm : mclaughlin','Project : McLaughlin Maps'])
      expect(@dsdoc.term_values(:otherId)).to match_array(["bb110sm8219","b382ee92-da77-11e0-9036-0016034322e4"])
      expect(@dsdoc.term_values(:sourceId)).to eq(['bb110sm8219'])
      expect(@dsdoc.objectId).to eq("druid:bb110sm8219")
      expect(@dsdoc.otherId).to eq(["mdtoolkit:bb110sm8219","uuid:b382ee92-da77-11e0-9036-0016034322e4"])
      expect(@dsdoc.otherId('mdtoolkit')).to eq(['bb110sm8219'])
      expect(@dsdoc.otherId('uuid')).to eq(['b382ee92-da77-11e0-9036-0016034322e4'])
      expect(@dsdoc.otherId('bogus')).to eq([])
      expect(@dsdoc.sourceId).to eq('sulair:bb110sm8219')
    end

    it "should be able to read ID fields as attributes" do
      expect(@dsdoc.objectId).to eq("druid:bb110sm8219")
      expect(@dsdoc.otherId).to eq(["mdtoolkit:bb110sm8219","uuid:b382ee92-da77-11e0-9036-0016034322e4"])
      expect(@dsdoc.otherId('mdtoolkit')).to eq(['bb110sm8219'])
      expect(@dsdoc.otherId('uuid')).to eq(['b382ee92-da77-11e0-9036-0016034322e4'])
      expect(@dsdoc.otherId('bogus')).to eq([])
      expect(@dsdoc.sourceId).to eq('sulair:bb110sm8219')
    end

    it "should be able to set the sourceID" do
      resultxml = <<-EOF
        <identityMetadata>
          <objectCreator>DOR</objectCreator>
          <objectId>druid:bb110sm8219</objectId>
          <objectLabel>AMERICQVE | SEPTENTRIONALE</objectLabel>
          <objectType>item</objectType>
          <otherId name="mdtoolkit">bb110sm8219</otherId>
          <otherId name="uuid">b382ee92-da77-11e0-9036-0016034322e4</otherId>
          <sourceId source="test">ab110cd8219</sourceId>
          <tag>MDForm : mclaughlin</tag>
          <tag>Project : McLaughlin Maps</tag>
        </identityMetadata>
      EOF

      @dsdoc.sourceId = 'test:ab110cd8219'
      expect(@dsdoc.sourceId).to eq('test:ab110cd8219')
      expect(@dsdoc.to_xml).to be_equivalent_to resultxml
    end

    it "creates a simple default with #new" do
      new_doc = Dor::IdentityMetadataDS.new nil, 'identityMetadata'
      expect(new_doc.to_xml).to be_equivalent_to '<identityMetadata/>'
    end

    it "should properly add elements" do
      resultxml = <<-EOF
        <identityMetadata>
          <objectId>druid:ab123cd4567</objectId>
          <otherId name="mdtoolkit">ab123cd4567</otherId>
          <otherId name="uuid">12345678-abcd-1234-ef01-23456789abcd</otherId>
          <tag>Created By : Spec Tests</tag>
        </identityMetadata>
      EOF
      new_doc = Dor::IdentityMetadataDS.new nil, 'identityMetadata'
      new_doc.add_value('objectId', 'druid:ab123cd4567')
      new_doc.add_value('otherId', '12345678-abcd-1234-ef01-23456789abcd', { 'name' => 'uuid' })
      new_doc.add_value('otherId', 'ab123cd4567', { 'name' => 'mdtoolkit' })
      new_doc.add_value('tag', 'Created By : Spec Tests')
      expect(new_doc.to_xml).to be_equivalent_to resultxml
      expect(new_doc.objectId).to eq('druid:ab123cd4567')
      expect(new_doc.otherId).to match_array(['mdtoolkit:ab123cd4567','uuid:12345678-abcd-1234-ef01-23456789abcd'])
    end
  end

end
