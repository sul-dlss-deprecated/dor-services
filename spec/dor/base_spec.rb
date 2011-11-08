require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'fakeweb'
require 'equivalent-xml'

class Local < Dor::Base
  
end

describe Dor::Base do
  
  before :all do
    @saved_configuration = Dor::Config.to_hash
    Dor::Config.configure do
      suri.mint_ids false
      gsearch.url "http://fedora.edu/solr"
      fedora.url "http://fedora.edu/fedora"
    end
    
    Rails.stub_chain(:logger, :error)
#    ActiveFedora::SolrService.register(Dor::Config.gsearch.url)
#    Fedora::Repository.register(Dor::Config.fedora.url)
    Fedora::Repository.stub!(:instance).and_return(stub('frepo').as_null_object)
  end

  after :each do
    FakeWeb.clean_registry
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
  
  it "should properly touch items that need reindexing" do
    FakeWeb.register_uri(:put, "http://fedora.edu/fedora/objects/druid:bb110sm8219?state=A", :body => '')
    FakeWeb.register_uri(:put, "http://fedora.edu/fedora/objects/druid:bb110sm8210?state=A", :body => '', :status => ['404','Not Found'])
    FakeWeb.register_uri(:post, "http://fedora.edu/solr/update", :body => '<?xml version="1.0" encoding="UTF-8"?><response><lst name="responseHeader"><int name="status">0</int><int name="QTime">6507</int></lst></response>')
    Dor::Base.touch('druid:bb110sm8219','druid:bb110sm8210').should == [200,200]
    FakeWeb.last_request.body.should be_equivalent_to '<update><delete><id>druid:bb110sm8210</id></delete></update>'
  end

end