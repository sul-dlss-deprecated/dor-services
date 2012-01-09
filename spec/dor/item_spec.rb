require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../foxml_helper')
require 'equivalent-xml'

describe Dor::Item do
  
  before :all do
    @fixture_dir = fixture_dir = File.join(File.dirname(__FILE__),"../fixtures")
    @saved_configuration = Dor::Config.to_hash
    Dor::Config.configure do
      suri.mint_ids false
      gsearch.url "http://solr.edu"
      fedora.url "http://fedora.edu"
      stacks.local_workspace_root File.join(fixture_dir, "workspace")
    end

    Rails.stub_chain(:logger, :error)
    ActiveFedora::SolrService.register(Dor::Config.gsearch.url)
    Fedora::Repository.register(Dor::Config.fedora.url)
  end
  
  before(:each) do
    Fedora::Repository.stub!(:instance).and_return(stub('frepo').as_null_object)
  end
  
  after :all do
    Dor::Config.configure(@saved_configuration)
  end
  
  it "has a contentMetadata datastream" do
    b = Dor::Item.new
    b.datastreams['contentMetadata'].class.should == ContentMetadataDS
  end
  
  describe "#generate_dublin_core" do
    it "produces dublin core from the MODS in the descMetadata datastream" do
      mods = IO.read(File.expand_path(File.dirname(__FILE__) + '/../fixtures/ex1_mods.xml'))
      expected_dc = IO.read(File.expand_path(File.dirname(__FILE__) + '/../fixtures/ex1_dc.xml'))
      
      b = Dor::Item.new
      descmd_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'descMetadata', :blob => mods)
      b.add_datastream(descmd_ds)
      
      dc = b.generate_dublin_core
      EquivalentXml.equivalent?(dc, expected_dc).should be
    end
    
    it "throws an exception if the generated dc has no root element" do
      b = Dor::Item.new
      descmd_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'descMetadata', :blob => '<tei><stuff>ha</stuff></tei')
      b.add_datastream(descmd_ds)
      
      lambda {b.generate_dublin_core}.should raise_error
    end
    
    it "throws an exception if the generated dc has only a root element with no children" do
      mods = <<-EOXML
        <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   version="3.3"
                   xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd" />          
      EOXML
      
      b = Dor::Item.new
      descmd_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'descMetadata', :blob => mods)
      b.add_datastream(descmd_ds)
      
      lambda {b.generate_dublin_core}.should raise_error
    end
  end
        
  describe "#public_xml" do
    
    context "produces xml with" do
        before(:each) do
          @b = Dor::Item.new
          @b.stub!(:pid).and_return('druid:123456')
          @now = Time.now
          Time.should_receive(:now).and_return(@now)

          mods = <<-EOXML
            <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       version="3.3"
                       xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd">
              <mods:identifier type="local" displayLabel="SUL Resource ID">druid:pz263ny9658</mods:identifier>
            </mods:mods>           
          EOXML
          descmd_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'descMetadata', :blob => mods)
          @b.add_datastream(descmd_ds)

          id_ds = IdentityMetadataDS.new(:dsid=> 'identityMetadata', :blob => '<identityMetadata/>')
          @b.add_datastream(id_ds)
          cm_ds = ContentMetadataDS.new(:dsid=> 'contentMetadata', :blob => '<contentMetadata/>')
          @b.add_datastream(cm_ds)
          r_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'rightsMetadata', :blob => '<rightsMetadata/>')
          @b.add_datastream(r_ds)
          @p_xml = Nokogiri::XML(@b.public_xml)
        end
        
       it "an id attribute" do
         @p_xml.at_xpath('/publicObject/@id').value.should =~ /^druid:123456/
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
       
       it "clones of the content of the other datastreams, keeping the originals in tact" do
         @b.datastreams['identityMetadata'].ng_xml.at_xpath("/identityMetadata").should be
         @b.datastreams['contentMetadata'].ng_xml.at_xpath("/contentMetadata").should be
         @b.datastreams['rightsMetadata'].ng_xml.at_xpath("/rightsMetadata").should be
       end
    end
  
    context "error handling" do
      it "throws an exception if any of the required datastreams are missing" do
        pending
      end
    end
  end
  
  describe "#publish_metadata" do
    
    it "does not publish the object unless rightsMetadata has world discover access" do
      item = Dor::Item.new
      item.stub!(:pid).and_return("druid:ab123bb4567")  
      rights = <<-EOXML
        <rightsMetadata objectId="druid:ab123bb4567">
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
      r_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'rightsMetadata', :blob => rights)
      item.add_datastream(r_ds)
      Dor::DigitalStacksService.should_not_receive(:transfer_to_document_store)

      item.publish_metadata
    end
        
    context "copies to the document cache" do
      
      it "identityMetadta, contentMetadata, rightsMetadata, generated dublin core, and public xml" do
        b = Dor::Item.new
        b.stub!(:pid).and_return('druid:ab123bb4567')

        mods = <<-EOXML
          <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                     version="3.3"
                     xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd">
            <mods:identifier type="local" displayLabel="SUL Resource ID">druid:pz263ny9658</mods:identifier>
          </mods:mods>           
        EOXML
        descmd_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'descMetadata', :blob => mods)
        b.add_datastream(descmd_ds)
        id_ds = IdentityMetadataDS.new(:dsid=> 'identityMetadata', :blob => '<identityMetadata/>')
        b.add_datastream(id_ds)
        cm_ds = ContentMetadataDS.new(:dsid=> 'contentMetadata', :blob => '<contentMetadata/>')
        b.add_datastream(cm_ds)
        rights = "<rightsMetadata><access type='discover'><machine><world/></machine></access></rightsMetadata>"
        r_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'rightsMetadata', :blob => rights)
        b.add_datastream(r_ds)

        Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123bb4567', /<identityMetadata\/>/, 'identityMetadata')
        Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123bb4567', /<contentMetadata\/>/, 'contentMetadata')
        Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123bb4567', /<rightsMetadata>/, 'rightsMetadata')
        Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123bb4567', /<oai_dc:dc/, 'dc')
        Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123bb4567', /<publicObject/, 'public')
        Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123bb4567', /<mods:mods/, 'mods')

        b.publish_metadata
      end
    end
  end
  
  describe "#shelve" do
    
    it "builds a list of filenames eligible for shelving to the Digital Stacks" do
      b = Dor::Item.new
      b.stub!(:pid).and_return('druid:ab123bb4567')

      content_md = File.read(File.join(@fixture_dir,"workspace/ab/123/cd/4567/content_metadata.xml"))

      c_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'contentMetadata', :blob => content_md)
      b.add_datastream(c_ds)
      
      Dor::DigitalStacksService.should_receive(:shelve_to_stacks).with('druid:ab123bb4567', ['1.html', '2.html'])
      # TODO figure out best place to keep workspace root
      b.shelve
    end
  end
  
  context "datastream builders" do
    before(:each) do
      @item = item_from_foxml(File.read(File.join(@fixture_dir,"item_druid_ab123cd4567.xml")), Dor::Item)
      @apo  = item_from_foxml(File.read(File.join(@fixture_dir,"apo_druid_fg890hi1234.xml")), Dor::AdminPolicyObject)
      @item.stub!(:admin_policy_object).and_return(@apo)
    end
    
    it "should build the descMetadata datastream" do
      Dor::MetadataService.class_eval { class << self; alias_method :_fetch, :fetch; end }
      Dor::MetadataService.should_receive(:fetch).with('barcode:36105049267078').and_return { Dor::MetadataService._fetch('barcode:36105049267078') }
      @item.datastreams['descMetadata'].ng_xml.to_s.should be_equivalent_to('<xml/>')
      @item.build_datastream('descMetadata')
      @item.datastreams['descMetadata'].ng_xml.to_s.should_not be_equivalent_to('<xml/>')
    end

    it "should build the contentMetadata datastream" do
      content_md = File.read(File.join(@fixture_dir,"workspace/ab/123/cd/4567/content_metadata.xml"))
      @item.datastreams['contentMetadata'].ng_xml.to_s.should be_equivalent_to('<xml/>')
      @item.build_datastream('contentMetadata')
      @item.datastreams['contentMetadata'].ng_xml.should be_equivalent_to(Nokogiri::XML(content_md))
    end

    it "should build the rightsMetadata datastream" do
      @item.datastreams['rightsMetadata'].ng_xml.to_s.should be_equivalent_to('<xml/>')
      @item.build_datastream('rightsMetadata')
      @item.datastreams['rightsMetadata'].ng_xml.to_s.should_not be_equivalent_to('<xml/>')
    end
    
    it "should build the provenanceMetadata datastream" do
      #puts @item.datastreams.keys.inspect
      @item.datastreams['provenanceMetadata'].ng_xml.to_s.should be_equivalent_to('<xml/>')
      @item.build_provenanceMetadata_datastream('workflow_id', 'event_text')
      #puts @item.datastreams['provenanceMetadata'].ng_xml.to_s
      @item.datastreams['provenanceMetadata'].ng_xml.to_s.should_not be_equivalent_to('<xml/>')
    end

    it "should build the technicalMetadata datastream" do
      @fixture_dir = fixture_dir = File.join(File.dirname(__FILE__),"../fixtures")
      Dor::Config.sdr.configure do
        local_workspace_root File.join(fixture_dir, "workspace")
        local_export_home File.join(fixture_dir, "export")
      end
      @item.datastreams['technicalMetadata'].ng_xml.to_s.should be_equivalent_to('<xml/>')
      #puts @item.datastreams['technicalMetadata'].ng_xml.to_s
      @item.build_datastream('technicalMetadata')
      #puts @item.datastreams['technicalMetadata'].ng_xml.to_s
      @item.datastreams['technicalMetadata'].ng_xml.to_s.should_not be_equivalent_to('<xml/>')
    end

  end

end