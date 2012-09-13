require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class DescribableItem < ActiveFedora::Base
	include Dor::Identifiable
	include Dor::Describable
	include Dor::Processable
end

describe Dor::Describable do
	before(:all) { stub_config	 }
	after(:all)	 { unstub_config }
	
	before :each do
		@item = instantiate_fixture('druid:ab123cd4567', DescribableItem)
		@obj= instantiate_fixture('druid:ab123cd4567', DescribableItem)
		@obj.datastreams['descMetadata'].content = read_fixture('ex1_mods.xml')
	end
	
	it "should have a descMetadata datastream" do
		@item.datastreams['descMetadata'].should be_a(Dor::DescMetadataDS)
	end
	
	it "should know its metadata format" do
		FakeWeb.register_uri(:get, "#{Dor::Config.metadata.catalog.url}/?barcode=36105049267078", :body => read_fixture('ab123cd4567_descMetadata.xml'))
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
		dc.should be_equivalent_to(expected_dc)
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
		
		lambda {b.generate_dublin_core}.should raise_error(Dor::Describable::CrosswalkError)
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
		
		lambda {b.generate_dublin_core}.should raise_error(Dor::Describable::CrosswalkError)
	end
	describe 'update_title' do
		it 'should update the title' do 
			found=false 
		
			@obj.update_title('new title')
			@obj.descMetadata.ng_xml.search('//mods:mods/mods:titleInfo/mods:title', 'mods' => 'http://www.loc.gov/mods/v3').each do |node|
			node.content.should == 'new title'
			found=true
			end
			found.should == true
		end
		it 'should raise an exception if the mods lacks a title' do
			@obj.update_title('new title')
			@obj.descMetadata.ng_xml.search('//mods:mods/mods:titleInfo/mods:title', 'mods' => 'http://www.loc.gov/mods/v3').each do |node|
				node.remove
			end 
			lambda {@obj.update_title('druid:oo201oo0001', 'new title')}.should raise_error
		end
	end
	describe 'add_identifier' do
		it 'should add an identifier' do
			@obj.add_identifier('type', 'new attribute')
			res=@obj.descMetadata.ng_xml.search('//mods:identifier[@type="type"]','mods' => 'http://www.loc.gov/mods/v3')
			res.length.should > 0
			res.each do |node|
			node.content.should == 'new attribute'
			end
		end	
	end
	describe 'delete_identifier' do
	  it 'should delete an identifier' do
	    @obj.add_identifier('type', 'new attribute')
		res=@obj.descMetadata.ng_xml.search('//mods:identifier[@type="type"]','mods' => 'http://www.loc.gov/mods/v3')
		res.length.should > 0
		res.each do |node|
		  node.content.should == 'new attribute'
		end
		@obj.delete_identifier('type', 'new attribute').should == true
		res=@obj.descMetadata.ng_xml.search('//mods:identifier[@type="type"]','mods' => 'http://www.loc.gov/mods/v3')
		res.length.should == 0 
	end
	it 'should return false if there was nothing to delete' do
		@obj.delete_identifier( 'type', 'new attribute').should == false
	end
end
	describe 'set_desc_metadata_using_label' do
		it 'should create basic mods using the object label' do
			@obj.datastreams['descMetadata'].content=''
			@obj.set_desc_metadata_using_label()
			@obj.datastreams['descMetadata'].ng_xml.should be_equivalent_to <<-XML
						<?xml version="1.0"?>
						<mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
							 <titleInfo>
									 <title>Foxml Test Object</title>
								</titleInfo>
						 </mods>
						 XML

		end
		it 'should throw an exception if there is content in the descriptive metadata stream' do
			lambda{@obj.set_desc_metadata_using_label()}.should raise_error 
		end
		it 'should run if there is content in the descriptive metadata stream and force is true' do
			@obj.set_desc_metadata_using_label(true)
			@obj.datastreams['descMetadata'].ng_xml.should be_equivalent_to <<-XML
						<?xml version="1.0"?>
						<mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
							 <titleInfo>
									 <title>Foxml Test Object</title>
								</titleInfo>
						 </mods>
						 XML
		end
	end
end
