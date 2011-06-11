require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'active_fedora'
require 'equivalent-xml'

class Local < Dor::Base
  
end

describe Dor::Base do
  
  before :all do
    @saved_configuration = Dor::Config.to_hash
    Dor::Config.configure do
      suri.mint_ids false
      gsearch.url "http://solr.edu"
      fedora.url "http://fedora.edu"
    end
    
    Rails.stub_chain(:logger, :error)
    ActiveFedora::SolrService.register(Dor::Config.gsearch.url)
    Fedora::Repository.register(Dor::Config.fedora.url)
    Fedora::Repository.stub!(:instance).and_return(stub('frepo').as_null_object)
  end
  
  after :all do
    Dor::Config.configure(@saved_configuration)
  end
      
  it "should be of Type ActiveFedora::Base" do    
    b = Dor::Base.new
    b.should be_kind_of(ActiveFedora::Base)
    
    l = Local.new
    l.should be_kind_of(Dor::Base)
  end
  
  it "has a contentMetadata datastream" do
    b = Dor::Base.new
    b.datastreams['contentMetadata'].class.should == ActiveFedora::NokogiriDatastream
  end
  
  describe "#generate_dublin_core" do
    it "produces dublin core from the MODS in the descMetadata datastream" do
      mods = IO.read(File.expand_path(File.dirname(__FILE__) + '/../fixtures/ex1_mods.xml'))
      expected_dc = IO.read(File.expand_path(File.dirname(__FILE__) + '/../fixtures/ex1_dc.xml'))
      
      b = Dor::Base.new
      descmd_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'descMetadata', :blob => mods)
      b.add_datastream(descmd_ds)
      
      dc = b.generate_dublin_core
      EquivalentXml.equivalent?(dc, expected_dc).should be
    end
  end
        
  describe "#public_xml" do
    
    context "produces xml with" do
        b = Dor::Base.new

        mods = <<-EOXML
          <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                     version="3.3"
                     xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd"/>
        EOXML
        descmd_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'descMetadata', :blob => mods)
        b.add_datastream(descmd_ds)

        id_ds = IdentityMetadataDS.new(:dsid=> 'identityMetadata', :blob => '<identityMetadata/>')
        b.add_datastream(id_ds)
        cm_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'contentMetadata', :blob => '<contentMetadata/>')
        b.add_datastream(cm_ds)
        r_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'rightsMetadata', :blob => '<rightsMetadata/>')
        b.add_datastream(r_ds)
        p_xml = Nokogiri::XML(b.public_xml)

       it "an id attribute" do
         p_xml.at_xpath('/publicObject/@id').value.should =~ /^druid:/
       end

       it "identityMetadata" do
         p_xml.at_xpath('/publicObject/identityMetadata').should be
       end

       it "contentMetadata" do
         p_xml.at_xpath('/publicObject/contentMetadata').should be
       end

       it "rightsMetadata" do
         p_xml.at_xpath('/publicObject/rightsMetadata').should be
       end

       it "generated dublin core" do         
         p_xml.at_xpath('/publicObject/oai_dc:dc', 'oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/').should be
       end
       
       it "clones of the content of the other datastreams, keeping the originals in tact" do
         b.datastreams['identityMetadata'].ng_xml.at_xpath("/identityMetadata").should be
         b.datastreams['contentMetadata'].ng_xml.at_xpath("/contentMetadata").should be
         b.datastreams['rightsMetadata'].ng_xml.at_xpath("/rightsMetadata").should be
       end
    end
  
    context "error handling" do
      it "throws an exception if any of the required datastreams are missing" do
        pending
      end
    end
  end
  
  describe "#publish_metadata" do
    
    context "copies to the document cache" do
      
      it "identityMetadta, contentMetadata, rightsMetadata, generated dublin core, and public xml" do
        b = Dor::Base.new
        b.stub!(:pid).and_return('druid:ab123bb4567')

        mods = <<-EOXML
          <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                     version="3.3"
                     xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd"/>
        EOXML
        descmd_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'descMetadata', :blob => mods)
        b.add_datastream(descmd_ds)
        id_ds = IdentityMetadataDS.new(:dsid=> 'identityMetadata', :blob => '<identityMetadata/>')
        b.add_datastream(id_ds)
        cm_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'contentMetadata', :blob => '<contentMetadata/>')
        b.add_datastream(cm_ds)
        r_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'rightsMetadata', :blob => '<rightsMetadata/>')
        b.add_datastream(r_ds)

        Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123bb4567', /<identityMetadata\/>/, 'identityMetadata')
        Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123bb4567', /<contentMetadata\/>/, 'contentMetadata')
        Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123bb4567', /<rightsMetadata\/>/, 'rightsMetadata')
        Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123bb4567', /<oai_dc:dc/, 'DC')
        Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123bb4567', /<publicObject/, 'public')

        b.publish_metadata
      end
      
    end
  end
  
  describe "#shelve" do
    
    it "builds a list of filenames eligible for shelving to the Digital Stacks" do
      b = Dor::Base.new
      b.stub!(:pid).and_return('druid:ab123bb4567')

      content_md = <<-EOXML
        <contentMetadata type="googleScannedBook" objectId="druid:ab123bb4567">
           <resource id="page1" sequence="1" type="page" objectId="druid:rr123ss4567">
              <attr name="pageType">Title</attr>
              <attr name="pageNumber">3</attr>
              <attr name="pageLabel">ii</attr>
              <attr name="googlePageTag">IMAGE_ON_PAGE,IMPLICIT_PAGE_NUMBER</attr>
              <file id="00000001.jp2" format="JPEG2000" mimetype="image/jp2" size="169627" shelve="no" deliver="no" preserve="yes">
                 <imageData height="800" width="1200">
                 <location type="url">http://service/druid/00000001.jp2</location>
                 <location type="path">/dor/workspace/...</location>
                 <checksum type="md5">56dd37697f05073168b9b58ddaccad0a</checksum>
                 <checksum type="sha1">884b7650725011de8a390800200c9a66</checksum>
              </file>
              <file id="1.html" format="text" mimetype="text/html" encoding="UTF-8" dataType="hocr" size="734" shelve="yes" deliver="no" preserve="yes">
                 <location type="url">http://service/druid/00000001.jp2</location>
                 <checksum type="md5">60dd37697f05073168b9b58ddaccad0a</checksum>
                 <checksum type="sha1">324b7650725011de8a390800200c9a66</checksum>
              </file>
           </resource>
           <resource id="page2" sequence="1" type="page" objectId="druid:rr123ss4567">
               <attr name="pageType">Title</attr>
               <attr name="pageNumber">3</attr>
               <attr name="pageLabel">ii</attr>
               <attr name="googlePageTag">IMAGE_ON_PAGE,IMPLICIT_PAGE_NUMBER</attr>
               <file id="00000001.jp2" format="JPEG2000" mimetype="image/jp2" size="169627" shelve="no" deliver="no" preserve="yes">
                  <imageData height="800" width="1200">
                  <location type="url">http://service/druid/00000001.jp2</location>
                  <location type="path">/dor/workspace/...</location>
                  <checksum type="md5">56dd37697f05073168b9b58ddaccad0a</checksum>
                  <checksum type="sha1">884b7650725011de8a390800200c9a66</checksum>
               </file>
               <file id="2.html" format="text" mimetype="text/html" encoding="UTF-8" dataType="hocr" size="734" shelve="yes" deliver="no" preserve="yes">
                  <location type="url">http://service/druid/00000001.jp2</location>
                  <checksum type="md5">60dd37697f05073168b9b58ddaccad0a</checksum>
                  <checksum type="sha1">324b7650725011de8a390800200c9a66</checksum>
               </file>
            </resource>
        </contentMetadata>
      EOXML
      c_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'contentMetadata', :blob => content_md)
      b.add_datastream(c_ds)
      
      Dor::DigitalStacksService.should_receive(:shelve_to_stacks).with('druid:ab123bb4567', ['1.html', '2.html'])
      # TODO figure out best place to keep workspace root
      b.shelve
    end
  end
end