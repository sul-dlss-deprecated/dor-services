# encoding: UTF-8
# frozen_string_literal: true

require 'spec_helper'
require 'nokogiri'

describe Dor::GeoMetadataDS do
  before :each do
    stub_config
    @doc = {}
    @test_keys = %w(co2_pipe oil_gas_fields)
    @test_keys.each do |k|
      @doc[k] = Dor::GeoMetadataDS.from_xml(read_fixture("geoMetadata_#{k}.xml"))
    end
    @template = Nokogiri::XML(read_fixture('geoMetadata_template.xml'))
  end

  context 'Exports' do
    it '#to_bbox' do
      @test_keys.each do |k|
        expect(@doc[k]).to be_a(Dor::GeoMetadataDS)
        expect(@doc[k].to_bbox.to_s).to eq({
          'co2_pipe' => Struct.new(:w, :e, :n, :s).new(-109.758319, -88.990844, 48.999336, 29.423028).to_s,
          'oil_gas_fields' => Struct.new(:w, :e, :n, :s).new(-151.479444, -78.085007, 69.4325, 26.071745).to_s
        }[k])
      end
    end

    it '#xml_template' do
      expect(Dor::GeoMetadataDS.xml_template.to_xml).to be_equivalent_to(@template)
    end

    it '#metadata' do
      expect(@doc['co2_pipe'].metadata.root.name).to eq('MD_Metadata')
      expect(@doc['co2_pipe'].metadata.root.children.size).to eq(33)
      expect(@doc['oil_gas_fields'].metadata.root.name).to eq('MD_Metadata')
      expect(@doc['oil_gas_fields'].metadata.root.children.size).to eq(33)
    end

    it '#feature_catalogue' do
      expect(@doc['co2_pipe'].feature_catalogue).not_to be_nil
      expect(@doc['co2_pipe'].feature_catalogue.root.name).to eq('FC_FeatureCatalogue')
      expect(@doc['co2_pipe'].feature_catalogue.root.children.size).to eq(17)
      expect(@doc['oil_gas_fields'].feature_catalogue).not_to be_nil
      expect(@doc['oil_gas_fields'].feature_catalogue.root.name).to eq('FC_FeatureCatalogue')
      expect(@doc['oil_gas_fields'].feature_catalogue.root.children.size).to eq(17)
    end
  end
end
