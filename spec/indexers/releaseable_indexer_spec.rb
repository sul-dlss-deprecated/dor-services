# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::ReleasableIndexer do
  let(:model) do
    Class.new(Dor::Abstract) do
      include Dor::Releaseable
    end
  end
  before { stub_config }

  after { unstub_config }

  let(:obj) { instantiate_fixture('druid:ab123cd4567', model) }

  describe 'to_solr' do
    let(:doc) { described_class.new(resource: obj).to_solr }

    it 'indexes release tags' do
      released_for_info = {
        'Project' => { 'release' => true }, 'test_target' => { 'release' => true }, 'test_nontarget' => { 'release' => false }
      }
      allow(obj).to receive(:released_for).and_return(released_for_info)
      released_to_field_name = Solrizer.solr_name('released_to', :symbol)
      expect(doc).to match a_hash_including(released_to_field_name => %w[Project test_target])
    end
  end
end
