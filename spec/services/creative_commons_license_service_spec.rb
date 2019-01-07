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
    it 'returns terms' do
      expect(described_class.property('by_sa').deprecation_warning).to match(/typo/)
    end
  end
end
