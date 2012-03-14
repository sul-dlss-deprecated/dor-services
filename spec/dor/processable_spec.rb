require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class ProcessableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
end

describe Dor::Processable do
  
  before(:all) { stub_config   }
  after(:all)  { unstub_config }
  
  before :each do
    @item = instantiate_fixture('druid:ab123cd4567', ProcessableItem)
    @item.contentMetadata.content = '<contentMetadata/>'
  end
  
  it "has a workflows datastream" do
    @item.datastreams['workflows'].should be_a(Dor::WorkflowDs)
  end
  
  context "filesystem-based content" do
    before :each do
      @filename = File.join(@fixture_dir, "workspace/ab/123/cd/4567/contentMetadata.xml")
      @content_md = read_fixture("workspace/ab/123/cd/4567/content_metadata.xml")
    end
    
    it "should read datastream content files from the workspace" do
      File.should_receive(:exists?).with(@filename).and_return(true)
      File.should_not_receive(:exists?).with(/content_metadata.xml/).and_return(true)
      File.should_receive(:read).with(@filename).and_return(@content_md)
      @item.build_datastream('contentMetadata',true)
      @item.datastreams['contentMetadata'].ng_xml.should be_equivalent_to(@content_md)
    end

    it "should use the datastream builder if the file doesn't exist" do
      File.should_receive(:exists?).with(@filename).and_return(false)
      File.should_receive(:exists?).with(/content_metadata.xml/).and_return(true)
      @item.build_datastream('contentMetadata',true)
      @item.datastreams['contentMetadata'].ng_xml.should be_equivalent_to(@content_md)
    end
  end

end
