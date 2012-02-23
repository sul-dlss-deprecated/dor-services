require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class ShelvableItem < ActiveFedora::Base
  include Dor::Shelvable
end

describe Dor::Shelvable do

  before(:all) { stub_config   }
  after(:all)  { unstub_config }

  before :each do
    @item = instantiate_fixture('druid:ab123cd4567', ShelvableItem)
  end

  it "builds a list of filenames eligible for shelving to the Digital Stacks" do
    content_md = read_fixture("workspace/ab/123/cd/4567/content_metadata.xml")
    @item.contentMetadata.content = content_md
    Dor::DigitalStacksService.should_receive(:shelve_to_stacks).with('druid:ab123cd4567', ['1.html', '2.html'])
    # TODO figure out best place to keep workspace root
    @item.shelve
  end
  
end