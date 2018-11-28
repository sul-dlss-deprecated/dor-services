require 'spec_helper'

RSpec.describe Dor::Collection do
  describe '#to_solr' do
    subject(:doc) { collection.to_solr }
    let(:collection) { described_class.new(pid: 'foo:123') }

    before { allow(Dor::Config.workflow.client).to receive(:get_milestones).and_return([]) }

    it { is_expected.to have_key :id }
  end
end
