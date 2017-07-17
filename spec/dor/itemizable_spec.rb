require 'spec_helper'

class ItemizableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
end

describe Dor::Itemizable do

  before(:each) { stub_config   }
  after(:each)  { unstub_config }

  before :each do
    @item = instantiate_fixture('druid:ab123cd4567', ItemizableItem)
    @item.contentMetadata.content = '<contentMetadata/>'
  end

  it "has a contentMetadata datastream" do
    expect(@item.datastreams['contentMetadata']).to be_a(Dor::ContentMetadataDS)
  end

  it "should retrieve a content diff" do
    skip
  end

end
