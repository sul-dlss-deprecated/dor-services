require 'spec_helper'

class GeoableItem < ActiveFedora::Base
  include Dor::Identifiable
  include Dor::Describable
  include Dor::Geoable
end

describe Dor::Geoable do
  after(:each)	{ unstub_config }

  before :each do
    stub_config
    @item = GeoableItem.new
  end

  it "should have a descMetadata datastream" do
    expect(@item.datastreams['descMetadata']).to be_a(Dor::DescMetadataDS)
  end

  it "should have a geoMetadata datastream" do
    expect(@item.datastreams['geoMetadata']).to be_a(Dor::GeoMetadataDS)
  end

  it "expected methods" do
    %w{build_geoMetadata_datastream fetch_geoMetadata_datastream}.each do |k|
      expect(@item.public_methods).to include(k.to_sym)
    end
  end

  it "expected constants" do
    expect(@item.datastreams['geoMetadata'].dsid).to eq('geoMetadata')
  end

end
