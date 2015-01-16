# encoding: UTF-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'
require 'equivalent-xml'
require 'dor/datastreams/geo_metadata_ds'
require 'pp'

describe Dor::GeoMetadataDS do

  before :each do
    stub_config
    @doc = {}
    @mods = {}
    @test_keys = %w{co2_pipe oil_gas_fields}
    @test_keys.each do |k|
      @doc[k] = Dor::GeoMetadataDS.from_xml(read_fixture "geoMetadata_#{k}.xml")
      @mods[k] = Nokogiri::XML(read_fixture "geoMetadata_#{k}_mods.xml")
    end
    @template = Nokogiri::XML(read_fixture "geoMetadata_template.xml")
    @doc['co2_pipe'].geometryType = 'LineString'
    @doc['oil_gas_fields'].geometryType = 'Point'
    @doc['co2_pipe'].zipName = 'data.zip'
    @doc['oil_gas_fields'].zipName = 'data.zip'
    @doc['co2_pipe'].purl = 'http://purl.stanford.edu/ww217dj0457'
    @doc['oil_gas_fields'].purl =  'http://purl.stanford.edu/cs838pw3418'
  end

  context 'Terminology' do

    it 'id' do
      @test_keys.each do |k|
        expect(@doc[k].term_values(:id)).to eq([{
          'co2_pipe' => 'http://purl.stanford.edu/ww217dj0457',
          'oil_gas_fields' => 'http://purl.stanford.edu/cs838pw3418'
        }[k]])
      end
    end
    
    it 'file_id' do
      @test_keys.each do |k|
        expect(@doc[k].term_values(:file_id)).to eq([{
          'co2_pipe' => 'FA6ED959-7DED-4722-B1FB-A85FB79725BA',
          'oil_gas_fields' => 'BBF1AEBF-51A8-46CD-8913-95B63390A2D0'
        }[k]])
      end
    end

    it 'format' do
      @test_keys.each do |k|
        expect(@doc[k].term_values(:format)).to eq([{
          'co2_pipe' => 'Shapefile',
          'oil_gas_fields' => 'Shapefile'
        }[k]])
      end
    end

    it 'metadata_language' do
      @test_keys.each do |k|
        expect(@doc[k].term_values(:metadata_language)).to eq([{
          'co2_pipe' => 'eng',
          'oil_gas_fields' => 'eng'
        }[k]])
      end
    end

    it 'title' do
      @test_keys.each do |k|
        expect(@doc[k].term_values(:title)).to eq([{
          'co2_pipe' => 'Carbon Dioxide (CO2) Pipelines in the United States, 2011',
          'oil_gas_fields' => 'Oil and Gas Fields in the United States, 2011'
        }[k]])
      end
    end

    it 'abstract' do
      @test_keys.each do |k|
        expect(@doc[k].term_values(:abstract)).to eq([{
          'co2_pipe' => 'Dataset represents locations of existing and proposed CO2 pipelines. Includes all interstate pipelines and major intrastate pipelines.',
          'oil_gas_fields' => 'Shows the locations and extents of oil and gas fields in the United States'
        }[k]])
      end
    end

    it 'purpose' do
      @test_keys.each do |k|
        expect(@doc[k].term_values(:purpose)).to eq([{
          'co2_pipe' => 'Locating Carbon Dioxide (CO2) pipelines in the United States.',
          'oil_gas_fields' => 'Locating and analysing United States oil and gas field data for use in geographic information systems.'
        }[k]])
      end
    end

    it 'metadata_dt' do
      @test_keys.each do |k|
        expect(@doc[k].term_values(:metadata_dt)).to eq([{
          'co2_pipe' => '2013-09-16',
          'oil_gas_fields' => '2013-09-16'
        }[k]])
      end
    end
  end

  context '# to_solr_spatial' do

    it '#to_solr3_bbox' do
      @test_keys.each do |k|
        expect(@doc[k]).to be_a(Dor::GeoMetadataDS)
        expect(@doc[k].to_solr_bbox(:solr3)).to eq({
          'co2_pipe' => '-109.758319 29.423028 -88.990844 48.999336',
          'oil_gas_fields' => '-151.479444 26.071745 -78.085007 69.4325'
          }[k])
      end
    end

    it '#to_solr3_centroid' do
      @test_keys.each do |k|
        expect(@doc[k]).to be_a(Dor::GeoMetadataDS)
        expect(@doc[k].to_solr_centroid(:solr3)).to eq({
          'co2_pipe' => "39.211182,-99.3745815",
          'oil_gas_fields' => "47.7521225,-114.78222550000001"
          }[k])
      end
    end

    it '#to_solr4_bbox' do
      @test_keys.each do |k|
        expect(@doc[k]).to be_a(Dor::GeoMetadataDS)
        expect(@doc[k].to_solr_bbox(:solr4)).to eq({
          'co2_pipe' => 'POLYGON((-109.758319 29.423028, -109.758319 48.999336, -88.990844 48.999336, -88.990844 29.423028, -109.758319 29.423028))',
          'oil_gas_fields' => 'POLYGON((-151.479444 26.071745, -151.479444 69.4325, -78.085007 69.4325, -78.085007 26.071745, -151.479444 26.071745))'
          }[k])
      end
    end

    it '#to_solr4_centroid' do
      @test_keys.each do |k|
        expect(@doc[k]).to be_a(Dor::GeoMetadataDS)
        expect(@doc[k].to_solr_centroid(:solr4)).to eq({
          'co2_pipe' => 'POINT(-99.3745815 39.211182)',
          'oil_gas_fields' => 'POINT(-114.78222550000001 47.7521225)'
          }[k])
      end
    end
  end

  context 'Exports' do

    it '#to_centroid' do
      @test_keys.each do |k|
        expect(@doc[k]).to be_a(Dor::GeoMetadataDS)
        expect(@doc[k].to_centroid).to eq({
          'co2_pipe' => [-99.3745815, 39.211182],
          'oil_gas_fields' =>  [-114.78222550000001, 47.7521225]
          }[k])
      end
    end

    it '#to_bbox' do
      @test_keys.each do |k|
        expect(@doc[k]).to be_a(Dor::GeoMetadataDS)
        expect(@doc[k].to_bbox.to_s).to eq({
          'co2_pipe' => Struct.new(:w, :e, :n, :s).new(-109.758319, -88.990844, 48.999336, 29.423028).to_s,
          'oil_gas_fields' =>  Struct.new(:w, :e, :n, :s).new(-151.479444, -78.085007, 69.4325, 26.071745).to_s
          }[k])
      end
    end

    it '#to_wkt' do
      w, s, e, n = [1.2, 3.4, 5.6, 7.8]
      expect(Dor::GeoMetadataDS.to_wkt([w, s])).to eq("POINT(#{w} #{s})")
      { :t1 => [[w, s], [e, n]],
        :t2 => [[w, n], [e, s]],
        :t3 => [[w, s], [e, n]]
      }.each do |k,v|
        expect(Dor::GeoMetadataDS.to_wkt(v[0], v[1])).to eq("POLYGON((#{w} #{s}, #{w} #{n}, #{e} #{n}, #{e} #{s}, #{w} #{s}))")
      end
    end

    it '#xml_template' do
      expect(Dor::GeoMetadataDS.xml_template.to_xml).to be_equivalent_to(@template)
    end

    it '#metadata' do
      expect(@doc['co2_pipe'].metadata.root.name).to eq('MD_Metadata')
      @doc['co2_pipe'].metadata.root.children.size == 33
      expect(@doc['oil_gas_fields'].metadata.root.name).to eq('MD_Metadata')
      @doc['oil_gas_fields'].metadata.root.children.size == 33
    end

    it '#feature_catalogue' do
      expect(@doc['co2_pipe'].feature_catalogue.nil?).to eq(false)
      expect(@doc['co2_pipe'].feature_catalogue.root.name).to eq('FC_FeatureCatalogue')
      expect(@doc['co2_pipe'].feature_catalogue.root.children.size).to eq(17)
      expect(@doc['oil_gas_fields'].feature_catalogue.nil?).to eq(false)
      expect(@doc['oil_gas_fields'].feature_catalogue.root.name).to eq('FC_FeatureCatalogue')
      expect(@doc['oil_gas_fields'].feature_catalogue.root.children.size).to eq(17)
    end

    it '#to_coordinates_ddmmss' do
      r = {
        '-109.758319 -- -88.990844/48.999336 -- 29.423028' =>
"W 109°45ʹ30ʺ--W 88°59ʹ27ʺ/N 48°59ʹ58ʺ--N 29°25ʹ23ʺ",
        '-180 -- 180/90 -- -90' =>
"W 180°--E 180°/N 90°--S 90°",
        '-180.0 -- 180.00000/0.000 -- -90' =>
"W 180°--E 180°/N 0°--S 90°",
        '-0 -- 180.00000/0.000 -- -90' =>
"E 0°--E 180°/N 0°--S 90°",
        '-10 -- 10/20 -- -20' =>
"W 10°--E 10°/N 20°--S 20°",
        '-1.25 -- 15.254167/0 -- 0' =>
"W 1°15ʹ--E 15°15ʹ15ʺ/N 0°--N 0°",
        '-10.186667 -- 15.271389/0 -- 0' =>
"W 10°11ʹ12ʺ--E 15°16ʹ17ʺ/N 0°--N 0°",
        '120.2 -- 18.316667/0 -- 0' =>
"E 120°12ʹ--E 18°19ʹ/N 0°--N 0°",
        '120.2 -- 18.316667/0 -- 0.0001' =>
"E 120°12ʹ--E 18°19ʹ/N 0°--N 0°" 
      }
      r.each do |k,v|
        expect(Dor::GeoMetadataDS.to_coordinates_ddmmss(k)).to eq(v)
      end
    end
    
    it "#to_mods" do
      @test_keys.each do |k|
        # File.open("tmp.xml", "w") {|f| f << @doc[k].to_mods.to_xml}
        expect(@doc[k].to_mods.to_xml).to be_equivalent_to(@mods[k].to_xml)
      end
    end
    
    it "#to_dc" do
      @test_keys.each do |k|
        File.open("tmp.xml", "w") {|f| f << @doc[k].to_dublin_core.to_xml}
      end
    end
  end
end
