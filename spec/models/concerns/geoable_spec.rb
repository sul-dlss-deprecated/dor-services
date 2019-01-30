# frozen_string_literal: true

require 'spec_helper'

class GeoableItem < ActiveFedora::Base
  include Dor::Identifiable
  include Dor::Geoable
end

describe Dor::Geoable do
  after { unstub_config }

  before do
    stub_config
    @item = GeoableItem.new
  end

  it 'has a geoMetadata datastream' do
    expect(@item.datastreams['geoMetadata']).to be_a(Dor::GeoMetadataDS)
  end

  it 'expected constants' do
    expect(@item.datastreams['geoMetadata'].dsid).to eq('geoMetadata')
  end
end
