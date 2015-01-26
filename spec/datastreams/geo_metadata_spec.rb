# encoding: UTF-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'
require 'equivalent-xml'
require 'dor/datastreams/geo_metadata_ds'

describe Dor::GeoMetadataDS do

  before :each do
    stub_config
    @doc = {}
    @test_keys = %w{co2_pipe oil_gas_fields}
    @test_keys.each do |k|
      @doc[k] = Dor::GeoMetadataDS.from_xml(read_fixture "geoMetadata_#{k}.xml")
    end
    @template = Nokogiri::XML(read_fixture "geoMetadata_template.xml")
  end


  context 'Exports' do

    it '#to_bbox' do
      @test_keys.each do |k|
        @doc[k].should be_a(Dor::GeoMetadataDS)
        @doc[k].to_bbox.to_s.should == {
          'co2_pipe' => Struct.new(:w, :e, :n, :s).new(-109.758319, -88.990844, 48.999336, 29.423028).to_s,
          'oil_gas_fields' =>  Struct.new(:w, :e, :n, :s).new(-151.479444, -78.085007, 69.4325, 26.071745).to_s
          }[k]
      end
    end

    it '#xml_template' do
      Dor::GeoMetadataDS.xml_template.to_xml.should be_equivalent_to(@template)
    end

    it '#metadata' do
      @doc['co2_pipe'].metadata.root.name.should == 'MD_Metadata'
      @doc['co2_pipe'].metadata.root.children.size == 33
      @doc['oil_gas_fields'].metadata.root.name.should == 'MD_Metadata'
      @doc['oil_gas_fields'].metadata.root.children.size == 33
    end

    it '#feature_catalogue' do
      @doc['co2_pipe'].feature_catalogue.nil?.should == false
      @doc['co2_pipe'].feature_catalogue.root.name.should == 'FC_FeatureCatalogue'
      @doc['co2_pipe'].feature_catalogue.root.children.size.should == 17
      @doc['oil_gas_fields'].feature_catalogue.nil?.should == false
      @doc['oil_gas_fields'].feature_catalogue.root.name.should == 'FC_FeatureCatalogue'
      @doc['oil_gas_fields'].feature_catalogue.root.children.size.should == 17
    end
  end
end
