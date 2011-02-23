require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'active_fedora'

class Local < Dor::Base
  
end

describe Dor::Base do
  
  it "should be of Type ActiveFedora::Base" do
    with_warnings_suppressed do
      Dor::MINT_SURI_IDS = false
      Dor::SOLR_URL = "http://solr.edu"
      Dor::FEDORA_URL = "http://fedora.edu"
    end
    Rails.stub_chain(:logger, :error)
    ActiveFedora::SolrService.register(Dor::SOLR_URL)
    Fedora::Repository.register(Dor::FEDORA_URL)
    Fedora::Repository.stub!(:instance).and_return(stub('frepo').as_null_object)
    
    b = Dor::Base.new
    b.should be_kind_of(ActiveFedora::Base)
    
    l = Local.new
    l.should be_kind_of(Dor::Base)
  end
  
end