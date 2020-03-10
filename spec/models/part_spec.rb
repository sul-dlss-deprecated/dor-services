# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Part do
  let(:part) do
    described_class.new
  end

  describe '#file_name' do
    subject { part.file_name }

    before do
      part.file_name = 'thesis.pdf'
    end

    it { is_expected.to eq 'thesis.pdf' }
  end

  describe '#size' do
    subject { part.size }

    before do
      part.size = '90000'
    end

    it { is_expected.to eq '90000' }
  end
end
