# frozen_string_literal: true

require 'spec_helper'

class SimpleItem < ActiveFedora::Base
  include Dor::Describable
end

RSpec::Matchers.define_negated_matcher :a_hash_excluding, :a_hash_including

RSpec.describe Dor::Describable do
  before { stub_config }

  after { unstub_config }

  before do
    @simple = instantiate_fixture('druid:ab123cd4567', SimpleItem)
    @item   = instantiate_fixture('druid:ab123cd4567', Dor::Item)
    @obj    = instantiate_fixture('druid:ab123cd4567', Dor::Item)
    @obj.datastreams['descMetadata'].content = read_fixture('ex1_mods.xml')
  end

  it 'has a descMetadata datastream' do
    expect(@item.datastreams['descMetadata']).to be_a(Dor::DescMetadataDS)
  end

  describe 'stanford_mods accessor to DS' do
    it 'fetches Stanford::Mods object' do
      expect(@obj.methods).to include(:stanford_mods)
      sm = nil
      expect { sm = @obj.stanford_mods }.not_to raise_error
      expect(sm).to be_kind_of(Stanford::Mods::Record)
      expect(sm.format_main).to eq(['Book'])
      expect(sm.pub_year_sort_str).to eq('1911')
    end
    it 'allows override argument(s)' do
      sm = nil
      nk = Nokogiri::XML('<mods><genre>ape</genre></mods>')
      expect { sm = @obj.stanford_mods(nk, false) }.not_to raise_error
      expect(sm).to be_kind_of(Stanford::Mods::Record)
      expect(sm.genre.text).to eq('ape')
      expect(sm.pub_year_sort_str).to be_nil
    end
  end
end
