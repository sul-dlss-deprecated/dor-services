require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class DescribableItem < ActiveFedora::Base
  include Dor::Identifiable
  include Dor::Describable
  include Dor::Processable
end

describe Dor::Describable do
  before(:all) { stub_config   }
  after(:all)  { unstub_config }
  
  before :each do
    @item = instantiate_fixture('druid:ab123cd4567', DescribableItem)
  end
  
  it "should have a descMetadata datastream" do
    @item.datastreams['descMetadata'].should be_a(DescMetadataDS)
  end
  
  it "should know its metadata format" do
    @item.metadata_format.should be_nil
    @item.build_datastream('descMetadata')
    @item.metadata_format.should == 'mods'
  end
  
  it "should provide a descMetadata datastream builder" do
    Dor::MetadataService.class_eval { class << self; alias_method :_fetch, :fetch; end }
    Dor::MetadataService.should_receive(:fetch).with('barcode:36105049267078').and_return { Dor::MetadataService._fetch('barcode:36105049267078') }
    @item.datastreams['descMetadata'].ng_xml.to_s.should be_equivalent_to('<xml/>')
    @item.build_datastream('descMetadata')
    @item.datastreams['descMetadata'].ng_xml.to_s.should_not be_equivalent_to('<xml/>')
  end
  
  it "produces dublin core from the MODS in the descMetadata datastream" do
    mods = read_fixture('ex1_mods.xml')
    expected_dc = read_fixture('ex1_dc.xml')
    
    b = DescribableItem.new
    b.datastreams['descMetadata'].content = mods
    
    dc = b.generate_dublin_core
    EquivalentXml.equivalent?(dc, expected_dc).should be
  end
  
  it "produces dublin core Stanford-specific mapping for repository, collection and location, from the MODS in the descMetadata datastream" do
    mods = read_fixture('ex2_related_mods.xml')
    expected_dc = read_fixture('ex2_related_dc.xml')
    
    b = DescribableItem.new
    b.datastreams['descMetadata'].content = mods
    
    dc = b.generate_dublin_core
    EquivalentXml.equivalent?(dc, expected_dc).should be
  end

  it "throws an exception if the generated dc has no root element" do
    b = DescribableItem.new
    b.datastreams['descMetadata'].content = '<tei><stuff>ha</stuff></tei>'
    
    lambda {b.generate_dublin_core}.should raise_error
  end
  
  it "throws an exception if the generated dc has only a root element with no children" do
    mods = <<-EOXML
      <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 version="3.3"
                 xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd" />          
    EOXML
    
    b = DescribableItem.new
    b.datastreams['descMetadata'].content = mods
    
    lambda {b.generate_dublin_core}.should raise_error
  end
end
