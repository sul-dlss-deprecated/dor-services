require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

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
    @item.datastreams['descMetadata'].should be_a(Dor::DescMetadataDS)
  end
  
  it "should have a geoMetadata datastream" do
    @item.datastreams['geoMetadata'].should be_a(Dor::GeoMetadataDS)
  end
  
  it "expected methods" do
    %w{build_geoMetadata_datastream fetch_geoMetadata_datastream}.each do |k|
      @item.public_methods.include?(k.to_sym).should == true
    end
  end
  
  it "expected constants" do
    @item.datastreams['geoMetadata'].dsid.should == 'geoMetadata'
  end

end
