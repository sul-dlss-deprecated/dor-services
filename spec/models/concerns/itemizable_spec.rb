# frozen_string_literal: true

require 'spec_helper'

class ItemizableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
end

RSpec.describe Dor::Itemizable do
  before do
    stub_config
    @item = instantiate_fixture('druid:bb046xn0881', ItemizableItem)
  end

  after { unstub_config }

  it 'has a contentMetadata datastream' do
    expect(@item.contentMetadata).to be_a(Dor::ContentMetadataDS)
  end
end
