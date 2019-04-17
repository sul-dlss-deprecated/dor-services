# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Publishable do
  before do
    Dor.configure do
      stacks do
        host 'stacks.stanford.edu'
      end
    end
  end

  let(:item) do
    instantiate_fixture('druid:ab123cd4567', Dor::Item)
  end

  it 'has a rightsMetadata datastream' do
    expect(item.datastreams['rightsMetadata']).to be_a(ActiveFedora::OmDatastream)
  end
end
