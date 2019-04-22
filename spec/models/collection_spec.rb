# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Collection do
  describe '.datastreams' do
    subject { described_class.ds_specs.keys }

    it do
      expect(subject).to match_array ['RELS-EXT', 'DC', 'identityMetadata',
                                      'events', 'rightsMetadata', 'descMetadata', 'versionMetadata',
                                      'workflows', 'provenanceMetadata']
    end
  end

  describe '#to_solr' do
    subject(:doc) { collection.to_solr }

    let(:collection) { described_class.new(pid: 'foo:123') }
    let(:wf_indexer) { instance_double(Dor::WorkflowsIndexer, to_solr: {}) }
    let(:process_indexer) { instance_double(Dor::ProcessableIndexer, to_solr: {}) }

    before do
      allow(Dor::WorkflowsIndexer).to receive(:new).and_return(wf_indexer)
      allow(Dor::ProcessableIndexer).to receive(:new).and_return(process_indexer)
    end

    it { is_expected.to have_key :id }
  end
end
