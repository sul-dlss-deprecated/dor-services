require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class ItemizableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
end

describe Dor::Itemizable do

  before(:all) { stub_config   }
  after(:all)  { unstub_config }

  before :each do
    @item = instantiate_fixture('druid:ab123cd4567', ItemizableItem)
    @item.contentMetadata.content = '<contentMetadata/>'
  end

  it "has a contentMetadata datastream" do
    @item.datastreams['contentMetadata'].should be_a(Dor::ContentMetadataDS)
  end
  
  it "should provide a contentMetadata datastream builder" do
    content_md = read_fixture("workspace/ab/123/cd/4567/content_metadata.xml")
    @item.datastreams['contentMetadata'].ng_xml.should_not be_equivalent_to(content_md)
    @item.build_datastream('contentMetadata',true)
    @item.datastreams['contentMetadata'].ng_xml.should be_equivalent_to(content_md)
  end
  
  it "should retrieve a content diff" do
  end

end