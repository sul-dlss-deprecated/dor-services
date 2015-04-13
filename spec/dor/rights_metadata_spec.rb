require 'spec_helper'

class RightsHaver < Dor::Item
#   include Dor::HasRightsMD
end

describe Dor::RightsMetadataDS do
  before(:each) { stub_config }
  after(:each)  { unstub_config }

  before(:each) do
    @item = instantiate_fixture('druid:oo201oo0001', RightsHaver)
    allow(@item).to receive(:new?).and_return(false)
    allow(@item).to receive(:workflows).and_return(double())
    ds = @item.rightsMetadata
    ds.instance_variable_set(:@datastream_content, @item.rightsMetadata.content)
    allow(ds).to receive(:new?).and_return(false)
    allow(Dor::Item).to receive(:find).with('druid:oo201oo0001').and_return(@item)
  end

  it "#new" do
    expect(Dor::RightsMetadataDS.new).to be_a(Dor::RightsMetadataDS)
  end

  it "should have a rightsMetadata datastream" do
    expect(@item).to be_a(RightsHaver)
    expect(@item).to be_kind_of(Dor::Item)
    skip "Not fully written"
    #  binding.pry
    expect(@item.datastreams['rightsMetadata']).to be_a(Dor::RightsMetadataDS)
  end

  describe 'to_solr' do
    it 'should have correct primary' do
      skip "Not fully written"
      doc=@item.to_solr
      #doc.keys.sort.each do |key|
      #  puts "#{key} #{doc[key]}"
      #end
      expect(doc['apo_title_facet'].first).to eq('druid:fg890hi1234')
    end
  end
end
