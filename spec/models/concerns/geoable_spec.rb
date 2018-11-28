# frozen_string_literal: true

require 'spec_helper'

class GeoableItem < ActiveFedora::Base
  include Dor::Identifiable
  include Dor::Geoable
end

describe Dor::Geoable do
  after(:each) { unstub_config }

  before :each do
    stub_config
    @item = GeoableItem.new
  end

  it 'should have a geoMetadata datastream' do
    expect(@item.datastreams['geoMetadata']).to be_a(Dor::GeoMetadataDS)
  end

  it 'expected constants' do
    expect(@item.datastreams['geoMetadata'].dsid).to eq('geoMetadata')
  end
end
