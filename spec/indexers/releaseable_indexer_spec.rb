# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::ReleasableIndexer do
  let(:model) do
    Class.new(Dor::Abstract)
  end
  before { stub_config }

  after { unstub_config }

  let(:obj) { instantiate_fixture('druid:ab123cd4567', model) }

  describe 'to_solr' do
    let(:doc) { described_class.new(resource: obj).to_solr }

    let(:released_for_info) do
      {
        'Project' => { 'release' => true },
        'test_target' => { 'release' => true },
        'test_nontarget' => { 'release' => false }
      }
    end
    let(:service) { instance_double(Dor::ReleaseTagService, released_for: released_for_info) }
    let(:released_to_field_name) { Solrizer.solr_name('released_to', :symbol) }

    before do
      allow(Dor::ReleaseTagService).to receive(:for).and_return(service)
    end

    it 'indexes release tags' do
      expect(doc).to match a_hash_including(released_to_field_name => %w[Project test_target])
    end
  end
end
