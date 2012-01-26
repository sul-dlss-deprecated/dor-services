require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class PublishableItem < ActiveFedora::Base
  include Dor::Publishable
  include Dor::Processable
end

describe Dor::Publishable do

  before(:all) { stub_config   }
  after(:all)  { unstub_config }
  
  before :each do
    @item = instantiate_fixture('druid:ab123cd4567', PublishableItem)
    @apo  = instantiate_fixture('druid:fg890hi1234', Dor::AdminPolicyObject)
    @item.stub!(:admin_policy_object).and_return(@apo)
    @mods = <<-EOXML
      <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 version="3.3"
                 xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd">
        <mods:identifier type="local" displayLabel="SUL Resource ID">druid:ab123cd4567</mods:identifier>
      </mods:mods>           
    EOXML
    
    @rights = <<-EOXML
      <rightsMetadata objectId="druid:ab123cd4567">
        <copyright>
          <human>(c) Copyright 2010 by Sebastian Jeremias Osterfeld</human>
        </copyright>
        </access>
        <access type="read">
          <machine>
            <group>stanford:stanford</group>
          </machine>
        </access>
        <use>
          <machine type="creativeCommons">by-sa</machine>
          <human type="creativeCommons">CC Attribution Share Alike license</human>
        </use>
      </rightsMetadata>
    EOXML
    
    @rels = <<-EOXML
      <rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:hydra="http://projecthydra.org/ns/relations#">
        <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
          <hydra:isGovernedBy rdf:resource="info:fedora/druid:789012"></hydra:isGovernedBy>
          <fedora-model:hasModel rdf:resource="info:fedora/hydra:commonMetadata"></fedora-model:hasModel>
          <fedora:isMemberOf rdf:resource="info:fedora/druid:987654"></fedora:isMemberOf>
          <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:987654"></fedora:isMemberOfCollection>
        </rdf:Description>
      </rdf:RDF>
    EOXML
    
    @item.contentMetadata.content = '<contentMetadata/>'
    @item.descMetadata.content = @mods
    @item.rightsMetadata.content = @rights
    @item.rels_ext.content = @rels
  end

  it "has a rightsMetadata datastream" do
    @item.datastreams['rightsMetadata'].should be_a(ActiveFedora::NokogiriDatastream)
  end

  it "should provide a rightsMetadata datastream builder" do
    rights_md = @apo.defaultObjectRights.content
    @item.datastreams['rightsMetadata'].ng_xml.to_s.should_not be_equivalent_to(rights_md)
    @item.build_datastream('rightsMetadata',true)
    @item.datastreams['rightsMetadata'].ng_xml.to_s.should be_equivalent_to(rights_md)
  end
  
  describe "#public_xml" do
    
    context "produces xml with" do
        before(:each) do
          @now = Time.now
          Time.should_receive(:now).and_return(@now)
          @p_xml = Nokogiri::XML(@item.public_xml)
        end
        
       it "an id attribute" do
         @p_xml.at_xpath('/publicObject/@id').value.should =~ /^druid:ab123cd4567/
       end
       
       it "a published attribute" do
         @p_xml.at_xpath('/publicObject/@published').value.should == @now.xmlschema
       end

       it "identityMetadata" do
         @p_xml.at_xpath('/publicObject/identityMetadata').should be
       end

       it "contentMetadata" do
         @p_xml.at_xpath('/publicObject/contentMetadata').should be
       end

       it "rightsMetadata" do
         @p_xml.at_xpath('/publicObject/rightsMetadata').should be
       end

       it "generated dublin core" do         
         @p_xml.at_xpath('/publicObject/oai_dc:dc', 'oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/').should be
       end
       
       it "relationships" do
         ns = { 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'hydra' => 'http://projecthydra.org/ns/relations#', 
           'fedora' => 'info:fedora/fedora-system:def/relations-external#', 'fedora-model' => 'info:fedora/fedora-system:def/model#' }
         @p_xml.at_xpath('/publicObject/rdf:RDF', ns).should be
         @p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOf', ns).should be
         @p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOfCollection', ns).should be
         @p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora-model:hasModel', ns).should_not be
         @p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/hydra:isGovernedBy', ns).should_not be
       end

       it "clones of the content of the other datastreams, keeping the originals in tact" do
         @item.datastreams['identityMetadata'].ng_xml.at_xpath("/identityMetadata").should be
         @item.datastreams['contentMetadata'].ng_xml.at_xpath("/contentMetadata").should be
         @item.datastreams['rightsMetadata'].ng_xml.at_xpath("/rightsMetadata").should be
         @item.datastreams['RELS-EXT'].content.should be_equivalent_to @rels
       end
    end
  

    describe "#publish_metadata" do

      it "does not publish the object unless rightsMetadata has world discover access" do
        @item.rightsMetadata.content = <<-EOXML
          <rightsMetadata objectId="druid:ab123cd4567">
            <copyright>
              <human>(c) Copyright 2010 by Sebastian Jeremias Osterfeld</human>
            </copyright>
            </access>
            <access type="read">
              <machine>
                <group>stanford:stanford</group>
              </machine>
            </access>
            <use>
              <machine type="creativeCommons">by-sa</machine>
              <human type="creativeCommons">CC Attribution Share Alike license</human>
            </use>
          </rightsMetadata>
        EOXML
        Dor::DigitalStacksService.should_not_receive(:transfer_to_document_store)
        @item.publish_metadata
      end

      context "copies to the document cache" do
        it "identityMetadta, contentMetadata, rightsMetadata, generated dublin core, and public xml" do
          @item.rightsMetadata.content = "<rightsMetadata><access type='discover'><machine><world/></machine></access></rightsMetadata>"

          Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123cd4567', /<identityMetadata/, 'identityMetadata')
          Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123cd4567', /<contentMetadata/, 'contentMetadata')
          Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123cd4567', /<rightsMetadata/, 'rightsMetadata')
          Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123cd4567', /<oai_dc:dc/, 'dc')
          Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123cd4567', /<publicObject/, 'public')
          Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123cd4567', /<mods:mods/, 'mods')

          @item.publish_metadata
        end
      end
    end

    context "error handling" do
      it "throws an exception if any of the required datastreams are missing" do
        pending
      end
    end
  end

end
