require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class RightsHaver < ActiveFedora::Base
#   include Dor::HasRightsMD
end

describe Dor::RightsMetadataDS do
  before(:each) { stub_config }
  after(:each)  { unstub_config }

  let(:item) do
    item = instantiate_fixture('druid:oo201oo0001', RightsHaver)
    allow(item).to receive(:new?).and_return(false)
    ds = item.rightsMetadata
    ds.instance_variable_set(:@datastream_content, item.rightsMetadata.content)
    allow(ds).to receive(:new?).and_return(false)
    item
  end

  it "should have an rightsMetadata datastream" do
    expect(item.datastreams['rightsMetadata']).to be_a(Dor::RightsMetadataDS)
  end

  describe 'to_solr' do
    it 'should have correct primary' do
      doc=item.to_solr
      #doc.keys.sort.each do |key|
      #  puts "#{key} #{doc[key]}"
      #end
      expect(doc['apo_title_facet'].first).to eq('druid:fg890hi1234')
    end
  end
end
