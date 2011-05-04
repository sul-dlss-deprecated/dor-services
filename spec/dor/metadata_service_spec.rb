require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'
require 'equivalent-xml/rspec_matchers'

describe Dor::MetadataService do
  
  before :all do
    @specdir = File.join(File.dirname(__FILE__),"..")
  end
  
  it "should register a new metadata handler" do
    handler = Class.new do
      def fetch(prefix, identifier)
        return identifier
      end

      def label(metadata)
        return "title: #{metadata}"
      end

      def prefixes
        ['test']
      end
    end
    Dor::MetadataService.register(handler).should be_a(handler)
    Dor::MetadataService.known_prefixes.should include(:test)
    Dor::MetadataService.fetch('test:12345').should == '12345'
    Dor::MetadataService.label_for('test:12345').should == 'title: 12345'
  end
  
  it "should raise an exception if an invalid handler is registered" do
    handler = Class.new
    lambda { Dor::MetadataService.register(handler) }.should raise_exception(TypeError)
  end
  
  it "should raise an exception if an unknown metadata type is requested" do
    lambda { Dor::MetadataService.fetch('foo:bar') }.should raise_exception(Dor::MetadataError)
  end
  
  describe "Symphony handler" do
    before :each do
      @mods = File.read(File.join(@specdir, 'test_data', 'mods_record.xml'))
      @mock_resource = mock('catalog-resource', :get => @mods)
      @mock_resource.stub!(:[]).and_return(@mock_resource)
      RestClient::Resource.should_receive(:new).with(Dor::Config[:catalog_url]).and_return(@mock_resource)
    end
    
    it "should fetch a record based on barcode" do
      @mock_resource.should_receive(:[]).with("?barcode=12345")
      Dor::MetadataService.fetch('barcode:12345').should be_equivalent_to(@mods)
    end

    it "should fetch a record based on catkey" do
      @mock_resource.should_receive(:[]).with("?catkey=12345")
      Dor::MetadataService.fetch('catkey:12345').should be_equivalent_to(@mods)
    end
    
    it "should return the MODS title as the label" do
      @mock_resource.should_receive(:[]).with("?barcode=12345")
      Dor::MetadataService.label_for('barcode:12345').should == 'The isomorphism and thermal properties of the feldspars'
    end
  end

  describe "Metadata Toolkit handler" do
    before :each do
      @mods = File.read(File.join(@specdir, 'test_data', 'mods_record.xml'))
      @exist_response = File.read(File.join(@specdir, 'test_data', 'exist_response.xml'))
      @mock_resource = mock('mdtoolkit-resource', :post => @exist_response)
      @mock_resource.stub!(:[]).and_return(@mock_resource)
      RestClient::Resource.should_receive(:new).with(Dor::Config[:exist_url]).and_return(@mock_resource)
    end
    
    it "should fetch a record based on a druid: prefix" do
      @mock_resource.should_receive(:post).with(/druid:abc123xyz/, :content_type => 'application/xquery')
      Dor::MetadataService.fetch('druid:abc123xyz').should be_equivalent_to(@mods)
    end

    it "should fetch a record based on an mdtoolkit: prefix" do
      @mock_resource.should_receive(:post).with(/druid:abc123xyz/, :content_type => 'application/xquery')
      Dor::MetadataService.fetch('mdtoolkit:abc123xyz').should be_equivalent_to(@mods)
    end
    
    it "should return the MODS title as the label" do
      Dor::MetadataService.label_for('druid:abc123xyz').should == 'The isomorphism and thermal properties of the feldspars'
    end
  end
  
end
