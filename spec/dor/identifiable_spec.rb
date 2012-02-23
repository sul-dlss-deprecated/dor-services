require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class IdentifiableItem < ActiveFedora::Base
  include Dor::Identifiable
end

describe Dor::Identifiable do
  before(:all) { stub_config   }
  after(:all)  { unstub_config }
  
  before :each do
    @item = instantiate_fixture('druid:ab123cd4567', IdentifiableItem)
  end
  
  it "should have an identityMetadata datastream" do
    @item.datastreams['identityMetadata'].should be_a(IdentityMetadataDS)
  end
  
  it "should provide an identity_metadata legacy wrapper" do
    @item.identity_metadata.should be_a(IdentityMetadata)
  end
end
