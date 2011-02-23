require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'
require 'equivalent-xml'
require 'xml_models/identity_metadata/identity_metadata'

describe IdentityMetadata do
  
  before :all do
    @specdir = File.join(File.dirname(__FILE__),"..")
    @data = {
      :object_id => 'druid:rt923jk342',
      :object_type => 'item',
      :object_label => 'google download barcode 36105049267078',
      :object_creator => 'DOR',
      :citation_title => 'Squirrels of North America',
      :citation_creator => 'Eder, Tamara, 1974-',
      :source_id => 'google:STANFORD_342837261527',
      :other_ids => ['barcode:342837261527', 'catkey:129483625', 'uuid:7f3da130-7b02-11de-8a39-0800200c9a66'],
      :admin_policy => 'druid:hx23ke9928',
      :tags => ['Google Books : Phase 1', 'Google Books : Scan source STANFORD']
    }
  end
  
  context "build from scratch" do

    before :each do
      @idm = IdentityMetadata.new
    end
  
    it "should serialize empty" do
      test_doc = Nokogiri::XML(@idm.to_xml)
      correct_doc = Nokogiri::XML(File.read(File.join(@specdir,"test_data/identity_metadata_empty.xml")))
      EquivalentXml.equivalent?(test_doc,correct_doc).should == true
    end
    
    it "should build proper identity metadata XML" do
      @idm.objectId = @data[:object_id]
      @idm.objectTypes << @data[:object_type]
      @idm.objectLabels << @data[:object_label]
      @idm.objectCreators << @data[:object_creator]
      @idm.citationTitle = @data[:citation_title]
      @idm.citationCreators << @data[:citation_creator]
      @idm.sourceId = @data[:source_id]
      @idm.objectAdminClass = @data[:admin_policy]
      @data[:other_ids].each { |id| @idm.add_identifier(id) }
      @data[:tags].each { |tag| @idm.add_tag(tag) }

      test_doc = Nokogiri::XML(@idm.to_xml)
      correct_doc = Nokogiri::XML(File.read(File.join(@specdir,"test_data/identity_metadata_full.xml")))
      
      EquivalentXml.equivalent?(test_doc,correct_doc).should == true
    end
  
  end
  
  context "read and parse" do
  
    before :each do
      @idm = IdentityMetadata.from_xml(File.read(File.join(@specdir,"test_data/identity_metadata_full.xml")))
    end
    
    it "should load the proper values" do
      @idm.objectId.should == @data[:object_id]
      @idm.objectTypes.should include(@data[:object_type])
      @idm.objectLabels.should include(@data[:object_label])
      @idm.objectCreators.should include(@data[:object_creator])
      @idm.citationTitle.should == @data[:citation_title]
      @idm.citationCreators.should include(@data[:citation_creator])
      @idm.sourceId.to_s.should == @data[:source_id]
      @idm.objectAdminClass.should  == @data[:admin_policy]
      @data[:other_ids].each { |id| @idm.get_id_pairs.should include(id) }
      @data[:tags].each { |tag| @idm.get_tags.should include(tag) }
    end
    
    it "should re-serialize correctly after a change" do
      @idm.add_tag('Test : Added by spec tests')
      test_doc = Nokogiri::XML(@idm.to_xml)
      correct_doc = Nokogiri::XML(File.read(File.join(@specdir,"test_data/identity_metadata_altered.xml")))
      
      EquivalentXml.equivalent?(test_doc,correct_doc).should == true
    end
    
  end
  
end
