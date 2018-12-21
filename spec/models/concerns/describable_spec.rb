# frozen_string_literal: true

require 'spec_helper'

class DescribableItem < ActiveFedora::Base
  include Dor::Identifiable
  include Dor::Describable
  include Dor::Processable
end
class SimpleItem < ActiveFedora::Base
  include Dor::Describable
end

RSpec::Matchers.define_negated_matcher :a_hash_excluding, :a_hash_including

RSpec.describe Dor::Describable do
  before { stub_config }
  after { unstub_config }

  before do
    @simple = instantiate_fixture('druid:ab123cd4567', SimpleItem)
    @item   = instantiate_fixture('druid:ab123cd4567', DescribableItem)
    @obj    = instantiate_fixture('druid:ab123cd4567', DescribableItem)
    @obj.datastreams['descMetadata'].content = read_fixture('ex1_mods.xml')
  end

  it 'should have a descMetadata datastream' do
    expect(@item.datastreams['descMetadata']).to be_a(Dor::DescMetadataDS)
  end

  describe '#build_descMetadata_datastream' do
    before do
      stub_request(:get, "#{Dor::Config.metadata.catalog.url}/?barcode=36105049267078").to_return(body: read_fixture('ab123cd4567_descMetadata.xml'))
    end

    it 'calls the catalog service' do
      expect(Dor::MetadataService).to receive(:fetch).with('barcode:36105049267078').and_call_original
      xml = <<-END_OF_XML
      <?xml version="1.0"?>
      <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.6" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-6.xsd">
        <titleInfo>
          <title/>
        </titleInfo>
      </mods>
      END_OF_XML
      expect(@item.datastreams['descMetadata'].ng_xml.to_s).to be_equivalent_to(xml)
      @item.build_descMetadata_datastream(@item.descMetadata)
      expect(@item.datastreams['descMetadata'].ng_xml.to_s).not_to be_equivalent_to(xml)
    end
  end

  describe '#generate_dublin_core' do
    it 'delegates to the DublinCoreService' do
      expect_any_instance_of(Dor::DublinCoreService).to receive(:to_xml)
      expect(Deprecation).to receive(:warn)
      @item.generate_dublin_core
    end
  end

  describe '#generate_public_desc_md' do
    it 'calls the PublicDescMetadataService' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::PublicDescMetadataService).to receive(:new).with(@item).and_return(instance_double(Dor::PublicDescMetadataService, to_xml: '<xml />'))
      expect(@item.generate_public_desc_md).to eq '<xml />'
    end
  end

  describe 'get_collection_title' do
    before(:each) do
      @item = instantiate_fixture('druid:ab123cd4567', Dor::Item)
    end
    it 'should get a titleInfo/title' do
      @item.descMetadata.content = <<-XML
      <?xml version="1.0"?>
      <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
      <titleInfo>
      <title>Foxml Test Object</title>
      </titleInfo>
      </mods>
      XML
      expect(Dor::Describable.get_collection_title(@item)).to eq 'Foxml Test Object'
    end

    it 'should include a subtitle if there is one' do
      @item.descMetadata.content = <<-XML
      <?xml version="1.0"?>
      <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
      <titleInfo>
      <title>Foxml Test Object</title>
      <subTitle>Hello world</note>
      </titleInfo>
      </mods>
      XML
      expect(Dor::Describable.get_collection_title(@item)).to eq 'Foxml Test Object : Hello world'
    end
  end

  describe 'set_desc_metadata_using_label' do
    it 'should create basic mods using the object label' do
      allow(@obj.datastreams['descMetadata']).to receive(:content).and_return ''
      @obj.set_desc_metadata_using_label
      expect(@obj.datastreams['descMetadata'].ng_xml).to be_equivalent_to <<-XML
      <?xml version="1.0"?>
      <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.6" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-6.xsd">
      <titleInfo>
      <title>Foxml Test Object</title>
      </titleInfo>
      </mods>
      XML
    end
    it 'should throw an exception if there is content in the descriptive metadata stream' do
      # @obj.stub(:descMetadata).and_return(ActiveFedora::OmDatastream.new)
      allow(@obj.descMetadata).to receive(:new?).and_return(false)
      expect{ @obj.set_desc_metadata_using_label }.to raise_error(StandardError)
    end
    it 'should run if there is content in the descriptive metadata stream and force is true' do
      allow(@obj.descMetadata).to receive(:new?).and_return(false)
      @obj.set_desc_metadata_using_label(true)
      expect(@obj.datastreams['descMetadata'].ng_xml).to be_equivalent_to <<-XML
      <?xml version="1.0"?>
      <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.6" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-6.xsd">
      <titleInfo>
      <title>Foxml Test Object</title>
      </titleInfo>
      </mods>
      XML
    end
  end

  describe 'stanford_mods accessor to DS' do
    it 'should fetch Stanford::Mods object' do
      expect(@obj.methods).to include(:stanford_mods)
      sm = nil
      expect{ sm = @obj.stanford_mods }.not_to raise_error
      expect(sm).to be_kind_of(Stanford::Mods::Record)
      expect(sm.format_main).to eq(['Book'])
      expect(sm.pub_year_sort_str).to eq('1911')
    end
    it 'should allow override argument(s)' do
      sm = nil
      nk = Nokogiri::XML('<mods><genre>ape</genre></mods>')
      expect{ sm = @obj.stanford_mods(nk, false) }.not_to raise_error
      expect(sm).to be_kind_of(Stanford::Mods::Record)
      expect(sm.genre.text).to eq('ape')
      expect(sm.pub_year_sort_str).to be_nil
    end
  end
end
