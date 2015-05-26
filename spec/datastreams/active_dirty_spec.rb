require 'spec_helper'

# or something only sorta *like* Dirty?  see: http://api.rubyonrails.org/classes/ActiveModel/Dirty.html
describe ActiveModel::Dirty do
  before(:each) { stub_config }
  after(:each)  { unstub_config }

  describe Dor::ContentMetadataDS do
    before :each do
      @item = instantiate_fixture('druid:ab123cd4567', Dor::Item)
      @cm = @item.contentMetadata
      expect(@cm.content_changed?).to be_falsey
      @xml = '<?xml version="1.0"?><contentMetadata objectId="druid:gw177fc7976" type="map" stacks="/specialstack" />'
      @cm.content = @xml
    end
    it "does conventional change detection" do
      expect(@cm.content_changed?).to be_truthy
      expect(@cm.changes).to match a_hash_including("ng_xml")
    end
    it "clear_changes_information" do
      @cm.send(:clear_changes_information)
      expect(@cm.changes).to eq({})
      expect(@cm.content_changed?).to be_falsey
      expect(@cm.changed?).to be_falsey
    end
    it "changes_applied" do
      @cm.send(:changes_applied)
      expect(@cm.changes).to eq({})
      expect(@cm.content_changed?).to be_falsey
      expect(@cm.changed?).to be_falsey
    end
    it "reset_profile_attributes" do
      @cm.send(:reset_profile_attributes)
      expect(@cm.changes).to eq({})
      expect(@cm.content_changed?).to be_falsey
      expect(@cm.changed?).to be_falsey
      expect(@cm.content).to be_equivalent_to @xml
    end
    it "save has to call changes_applied" do
      expect(@cm).to receive(:changes_applied).with(no_args).and_call_original
      @cm.save
    end
    it "save has intended effects" do
      @cm.save
      expect(@cm.content_changed?).to be_falsey
      expect(@cm.changed?).to be_falsey
      expect(@cm.changes).to eq({})
    end
  end
end
