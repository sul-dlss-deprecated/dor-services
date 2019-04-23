# frozen_string_literal: true

require 'spec_helper'

describe Dor::Geoable do
  after { unstub_config }

  before do
    stub_config
    @item = Dor::Item.new
  end

  it 'has a geoMetadata datastream' do
    expect(@item.datastreams['geoMetadata']).to be_a(Dor::GeoMetadataDS)
  end

  it 'expected constants' do
    expect(@item.datastreams['geoMetadata'].dsid).to eq('geoMetadata')
  end
end
