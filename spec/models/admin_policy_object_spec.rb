# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::AdminPolicyObject do
  describe 'datastreams' do
    subject { described_class.ds_specs.keys }
    it do
      is_expected.to eq ['RELS-EXT', 'DC', 'identityMetadata',
                         'events', 'rightsMetadata', 'descMetadata', 'versionMetadata',
                         'workflows', 'administrativeMetadata', 'roleMetadata',
                         'defaultObjectRights']
    end
  end

  describe '#to_solr' do
    subject(:doc) { apo.to_solr }
    let(:apo) { described_class.new(pid: 'foo:123') }

    before { allow(Dor::Config.workflow.client).to receive(:get_milestones).and_return([]) }

    it { is_expected.to include 'active_fedora_model_ssi' => 'Dor::AdminPolicyObject' }
  end
end
