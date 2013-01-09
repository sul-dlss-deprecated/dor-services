require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'
require 'equivalent-xml'
require 'dor/datastreams/identity_metadata_ds'

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
    describe 'tosolr' do
      it 'should create a cretor_title field' do
        res={}
        @dsdoc.to_solr(res)
        res['creator_title_sort'].first.should == 'DORAMERICQVE | SEPTENTRIONALE'
      end
    end
    it "creates itself from xml" do
      @dsdoc.term_values(:objectId).should == ['druid:bb110sm8219']
      @dsdoc.term_values(:objectType).should == ['item']
      @dsdoc.term_values(:objectLabel).should == ['AMERICQVE | SEPTENTRIONALE']
      @dsdoc.term_values(:tag).should =~ ['MDForm : mclaughlin','Project : McLaughlin Maps']
      @dsdoc.term_values(:otherId).should =~ ["bb110sm8219","b382ee92-da77-11e0-9036-0016034322e4"]
      @dsdoc.term_values(:sourceId).should == ['bb110sm8219']
      @dsdoc.objectId.should == "druid:bb110sm8219"
      @dsdoc.otherId.should == ["mdtoolkit:bb110sm8219","uuid:b382ee92-da77-11e0-9036-0016034322e4"]
      @dsdoc.otherId('mdtoolkit').should == ['bb110sm8219']
      @dsdoc.otherId('uuid').should == ['b382ee92-da77-11e0-9036-0016034322e4']
      @dsdoc.otherId('bogus').should == []
      @dsdoc.sourceId.should == 'sulair:bb110sm8219'
    end
    
    it "should be able to read ID fields as attributes" do
      @dsdoc.objectId.should == "druid:bb110sm8219"
      @dsdoc.otherId.should == ["mdtoolkit:bb110sm8219","uuid:b382ee92-da77-11e0-9036-0016034322e4"]
      @dsdoc.otherId('mdtoolkit').should == ['bb110sm8219']
      @dsdoc.otherId('uuid').should == ['b382ee92-da77-11e0-9036-0016034322e4']
      @dsdoc.otherId('bogus').should == []
      @dsdoc.sourceId.should == 'sulair:bb110sm8219'
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
      @dsdoc.sourceId.should == 'test:ab110cd8219'
      @dsdoc.to_xml.should be_equivalent_to resultxml
    end
    
    it "creates a simple default with #new" do
      new_doc = Dor::IdentityMetadataDS.new nil, 'identityMetadata'
      new_doc.to_xml.should be_equivalent_to '<identityMetadata/>'
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
      new_doc.to_xml.should be_equivalent_to resultxml
      new_doc.objectId.should == 'druid:ab123cd4567'
      new_doc.otherId.should =~ ['mdtoolkit:ab123cd4567','uuid:12345678-abcd-1234-ef01-23456789abcd']
    end
  end
end