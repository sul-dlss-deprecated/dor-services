require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'active_fedora'

class Local < Dor::Base
  
end

describe Dor::Base do
  
  it "should be of Type ActiveFedora::Base" do
    Dor::Config.configure do |config|
      config.mint_suri_ids = false
      config.solr_url = "http://solr.edu"
      config.fedora_url = "http://fedora.edu"
    end
    Rails.stub_chain(:logger, :error)
    ActiveFedora::SolrService.register(Dor::Config[:solr_url])
    Fedora::Repository.register(Dor::Config[:fedora_url])
    Fedora::Repository.stub!(:instance).and_return(stub('frepo').as_null_object)
    
    b = Dor::Base.new
    b.should be_kind_of(ActiveFedora::Base)
    
    l = Local.new
    l.should be_kind_of(Dor::Base)
  end
  
end