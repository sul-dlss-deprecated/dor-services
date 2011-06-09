require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'active_fedora'

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
  
  describe "#generate_dublic_core" do
    
  end
    
  describe "#public_xml" do
    
    context "produces xml with" do
      
       b = Dor::Base.new
       id_ds = ActiveFedora::NokogiriDatastream.new(:dsid=> 'identityMetadata', :blob => '<identityMetadata/>')
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
         pending
       end
    end
  
    context "error handling" do
      it "throws an exception if any of the required datastreams are missing" do
        pending
      end
    end
  end
  
  
end