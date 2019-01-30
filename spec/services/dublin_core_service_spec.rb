# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::DublinCoreService do
  subject(:service) { described_class.new(item) }

  let(:item) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }

  describe '#ng_xml' do
    subject(:xml) { service.ng_xml }

    it 'produces dublin core from the MODS in the descMetadata datastream' do
      item.descMetadata.content = read_fixture('ex1_mods.xml')
      expect(xml).to be_equivalent_to read_fixture('ex1_dc.xml')
    end

    it 'produces dublin core Stanford-specific mapping for repository, collection and location, from the MODS in the descMetadata datastream' do
      item.descMetadata.content = read_fixture('ex2_related_mods.xml')
      expect(xml).to be_equivalent_to read_fixture('ex2_related_dc.xml')
    end

    it 'throws an exception if the generated dc has only a root element with no children' do
      mods = <<-EOXML
      <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      version="3.3"
      xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd" />
      EOXML

      item.descMetadata.content = mods
      expect { xml }.to raise_error(Dor::DublinCoreService::CrosswalkError)
    end
  end
end
