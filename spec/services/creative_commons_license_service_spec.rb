# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::CreativeCommonsLicenseService do
  describe '#map' do
    it 'maps stuff' do
      expect(Deprecation).to receive(:warn)
      expect(described_class.map { 1 }.sum).to eq 8
    end
  end

  describe '#include?' do
    it 'is true when the data has something' do
      expect(Deprecation).to receive(:warn)
      expect(described_class.include?('by-sa')).to be true
    end
  end

  describe '#property' do
    subject(:property) { described_class.property('by_sa') }

    it 'returns a term' do
      expect(property.deprecation_warning).to match(/typo/)
      expect(property.key).to eq 'by_sa'
    end
  end
end
