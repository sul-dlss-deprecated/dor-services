# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::PidUtils do
  describe '#remove_druid_prefix' do
    subject(:remove_druid_prefix) { described_class.remove_druid_prefix(pid) }

    let(:pid) { 'druid:ab123cd4567' }

    it 'removes the druid prefix if it is present' do
      expect(remove_druid_prefix).to eq('ab123cd4567')
    end

    context 'when the druid prefix is already stripped' do
      let(:pid) { 'oo000oo0001' }

      it 'leaves the string unchanged ' do
        expect(remove_druid_prefix).to eq('oo000oo0001')
      end
    end

    context 'when it is not a druid' do
      let(:pid) { 'bogus' }

      it 'returns the input string' do
        expect(remove_druid_prefix).to eq('bogus')
      end
    end
  end

  describe 'PID_REGEX' do
    subject(:regex) { described_class::PID_REGEX }

    it 'identifies pids by regex' do
      expect('ab123cd4567'.match(regex).size).to eq(1)
    end

    it 'pulls out a pid by regex' do
      expect('druid:ab123cd4567/other crappola'.match(regex)[0]).to eq('ab123cd4567')
    end

    it 'does not identify non-pids' do
      expect('bogus'.match(regex)).to be_nil
    end
  end
end
