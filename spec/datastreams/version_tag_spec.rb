# frozen_string_literal: true

require 'spec_helper'

describe Dor::VersionTag do
  describe '.parse' do
    it 'parses a String into a VersionTag object' do
      t = Dor::VersionTag.parse('1.1.0')
      expect(t.major).to eq(1)
      expect(t.minor).to eq(1)
      expect(t.admin).to eq(0)
    end
  end

  describe '#increment' do
    let(:tag) { Dor::VersionTag.parse('1.2.3')  }

    it 'adds 1 to major and zeros out minor and admin when :major is passed in' do
      tag.increment(:major)
      expect(tag.major).to eq(2)
      expect(tag.minor).to eq(0)
      expect(tag.admin).to eq(0)
    end

    it 'adds 1 to minor and zeros out admin when :minor is passed in' do
      tag.increment(:minor)
      expect(tag.minor).to eq(3)
      expect(tag.admin).to eq(0)
    end

    it 'adds 1 to admin when :admin is passed in' do
      tag.increment(:admin)
      expect(tag.admin).to eq(4)
    end
  end

  describe 'ordering' do
    it 'handles <, >, == comparisons' do
      v1 = Dor::VersionTag.new(1, 1, 0)
      v2 = Dor::VersionTag.new(1, 1, 2)
      expect(v1).to be < v2

      v3 = Dor::VersionTag.new(0, 1, 1)
      expect(v1).to be > v3

      v4 = Dor::VersionTag.new(1, 1, 0)
      expect(v1).to eq(v4)
    end
  end
end
