require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class ShelvableItem < ActiveFedora::Base
  include Dor::Shelvable
end

describe Dor::Shelvable do

  before(:all) { stub_config   }
  after(:all)  { unstub_config }

  before :each do
    @item = ShelvableItem.new :pid => 'druid:gj642zf5650'
    @item.contentMetadata.content = read_fixture("gj642zf5650_contentMetadata.xml")
  end
  
  after :each do
    @item.clear_diff_cache
  end

  it "builds a list of filenames eligible for shelving to the Digital Stacks" do
    FakeWeb.register_uri :post, "#{Dor::Config.sdr.url}/objects/druid:gj642zf5650/cm-inv-diff?subset=shelve", :body => read_fixture('shelvable_spec_diff.xml')
    Dor::DigitalStacksService.should_receive(:shelve_to_stacks).with(@item.pid, ['page-3.jpg','page-4.jpg'])
    Dor::DigitalStacksService.should_receive(:remove_from_stacks).with(@item.pid, ['title.jpg'])
    Dor::DigitalStacksService.should_receive(:rename_in_stacks).with(@item.pid, [['page-2.jpg','page-2a.jpg']])
    @item.shelve
  end
  
end