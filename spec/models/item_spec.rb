# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Item do
  describe '#to_solr' do
    subject(:doc) { item.to_solr }
    let(:item) { described_class.new(pid: 'foo:123') }

    before { allow(Dor::Config.workflow.client).to receive(:get_milestones).and_return([]) }

    it { is_expected.to include 'active_fedora_model_ssi' => 'Dor::Item' }
  end
end
