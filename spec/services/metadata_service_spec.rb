# frozen_string_literal: true

require 'spec_helper'

describe Dor::MetadataService do
  before :all do
    @specdir = File.join(File.dirname(__FILE__), '..')
  end

  it 'raises an exception if an unknown metadata type is requested' do
    expect { described_class.fetch('foo:bar') }.to raise_exception(Dor::MetadataError)
  end

  describe 'Symphony handler' do
    before do
      @mods = File.read(File.join(@specdir, 'fixtures', 'mods_record.xml'))
      @mock_resource = double('catalog-resource', get: @mods)
      allow(@mock_resource).to receive(:[]).and_return(@mock_resource)
      expect(RestClient::Resource).to receive(:new).with(Dor::Config.metadata.catalog.url,
                                                         Dor::Config.metadata.catalog.user,
                                                         Dor::Config.metadata.catalog.pass).and_return(@mock_resource)
    end

    it 'fetches a record based on barcode' do
      expect(@mock_resource).to receive(:[]).with('?barcode=12345')
      expect(described_class.fetch('barcode:12345')).to be_equivalent_to(@mods)
    end

    it 'fetches a record based on catkey' do
      expect(@mock_resource).to receive(:[]).with('?catkey=12345')
      expect(described_class.fetch('catkey:12345')).to be_equivalent_to(@mods)
    end

    it 'returns the MODS title as the label' do
      expect(@mock_resource).to receive(:[]).with('?barcode=12345')
      expect(described_class.label_for('barcode:12345')).to eq('The isomorphism and thermal properties of the feldspars')
    end
  end
end
