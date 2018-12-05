# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Collection do
  describe '.datastreams' do
    subject { described_class.ds_specs.keys }
    it do
      is_expected.to match_array ['RELS-EXT', 'DC', 'identityMetadata',
                                  'events', 'rightsMetadata', 'descMetadata', 'versionMetadata',
                                  'workflows', 'provenanceMetadata']
    end
  end

  describe '#to_solr' do
    subject(:doc) { collection.to_solr }
    let(:collection) { described_class.new(pid: 'foo:123') }

    before { allow(Dor::Config.workflow.client).to receive(:get_milestones).and_return([]) }

    it { is_expected.to have_key :id }
  end
end
