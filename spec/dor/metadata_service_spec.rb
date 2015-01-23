require 'spec_helper'
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
    expect(Dor::MetadataService.register(handler)).to be_a(handler)
    expect(Dor::MetadataService.known_prefixes).to include(:test)
    expect(Dor::MetadataService.fetch('test:12345')).to eq('12345')
    expect(Dor::MetadataService.label_for('test:12345')).to eq('title: 12345')
  end

  it "should raise an exception if an invalid handler is registered" do
    handler = Class.new
    expect { Dor::MetadataService.register(handler) }.to raise_exception(TypeError)
  end

  it "should raise an exception if an unknown metadata type is requested" do
    expect { Dor::MetadataService.fetch('foo:bar') }.to raise_exception(Dor::MetadataError)
  end

  describe "Symphony handler" do
    before :each do
      @mods = File.read(File.join(@specdir, 'fixtures', 'mods_record.xml'))
      @mock_resource = double('catalog-resource', :get => @mods)
      allow(@mock_resource).to receive(:[]).and_return(@mock_resource)
      expect(RestClient::Resource).to receive(:new).with(Dor::Config.metadata.catalog.url).and_return(@mock_resource)
    end

    it "should fetch a record based on barcode" do
      expect(@mock_resource).to receive(:[]).with("?barcode=12345")
      expect(Dor::MetadataService.fetch('barcode:12345')).to be_equivalent_to(@mods)
    end

    it "should fetch a record based on catkey" do
      expect(@mock_resource).to receive(:[]).with("?catkey=12345")
      expect(Dor::MetadataService.fetch('catkey:12345')).to be_equivalent_to(@mods)
    end

    it "should return the MODS title as the label" do
      expect(@mock_resource).to receive(:[]).with("?barcode=12345")
      expect(Dor::MetadataService.label_for('barcode:12345')).to eq('The isomorphism and thermal properties of the feldspars')
    end
  end

  describe "Metadata Toolkit handler" do
    before :each do
      @mods = File.read(File.join(@specdir, 'fixtures', 'mods_record.xml'))
      @exist_response = File.read(File.join(@specdir, 'fixtures', 'exist_response.xml'))
      @mock_resource = double('mdtoolkit-resource', :post => @exist_response)
      allow(@mock_resource).to receive(:[]).and_return(@mock_resource)
      expect(RestClient::Resource).to receive(:new).with(Dor::Config.metadata.exist.url).and_return(@mock_resource)
    end

    it "should fetch a record based on a druid: prefix" do
      expect(@mock_resource).to receive(:post).with(%r{contains\(base-uri\(\), "abc123xyz"\)}, :content_type => 'application/xquery')
      expect(Dor::MetadataService.fetch('druid:abc123xyz')).to be_equivalent_to(@mods)
    end

    it "should fetch a record based on an mdtoolkit: prefix" do
      expect(@mock_resource).to receive(:post).with(%r{contains\(base-uri\(\), "abc123xyz"\)}, :content_type => 'application/xquery')
      expect(Dor::MetadataService.fetch('mdtoolkit:abc123xyz')).to be_equivalent_to(@mods)
    end

    it "should return the MODS title as the label" do
      expect(Dor::MetadataService.label_for('druid:abc123xyz')).to eq('The isomorphism and thermal properties of the feldspars')
    end
  end

end
