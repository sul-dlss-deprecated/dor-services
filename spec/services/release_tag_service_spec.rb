# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::ReleaseTagService do
  before do
    allow(Deprecation).to receive(:warn)
    allow(Dor::Config.stacks).to receive(:document_cache_host).and_return('purl-test.stanford.edu')
  end

  let(:item) { instantiate_fixture('druid:bb004bn8654', Dor::Item) }
  let(:releases) { described_class.for(item) }
  let(:bryar_trans_am_admin_tags) { item.tags }
  let(:array_of_times) do
    ['2015-01-06 23:33:47Z', '2015-01-07 23:33:47Z', '2015-01-08 23:33:47Z', '2015-01-09 23:33:47Z'].map { |x| Time.parse(x).iso8601 }
  end

  describe 'Tag sorting, combining, and comparision functions' do
    let(:dummy_tags) do
      [
        { 'when' => array_of_times[0], 'tag' => "Project: Jim Harbaugh's Finest Moments At Stanford.", 'what' => 'self' },
        { 'when' => array_of_times[1], 'tag' => "Project: Jim Harbaugh's Even Finer Moments At Michigan.", 'what' => 'collection' }
      ]
    end

    describe '#newest_release_tag' do
      subject { releases.newest_release_tag(dummy_hash) }

      let(:dummy_hash) { { 'Revs' => dummy_tags, 'FRDA' => dummy_tags } }

      it { is_expected.to eq('Revs' => dummy_tags[1], 'FRDA' => dummy_tags[1]) }
    end
  end

  describe 'handling tags on objects and determining release status' do
    let(:item) { instantiate_fixture('druid:vs298kg2555', Dor::Item) }

    it 'uses only the most recent self tag to determine if an item is released, with no release tags on the collection' do
      stub_request(:get, 'https://purl-test.stanford.edu/vs298kg2555.xml')
        .and_return(status: 404)
      expect(releases.released_for(skip_live_purl: false)['Kurita']['release']).to be_truthy
    end

    context 'with a bad collection record that references itself' do
      let(:item) { instantiate_fixture('druid:wz243gf4151', Dor::Item) }

      before do
        stub_request(:get, 'https://purl-test.stanford.edu/wz243gf4151.xml')
          .and_return(status: 404)
      end

      it 'does not end up in an infinite loop by skipping the tag check for itself' do
        allow(item).to receive(:collections).and_return([item]) # force it to return itself as a member
        expect(item.collections.first.id).to eq item.id # confirm it is a member of itself
        expect(releases.released_for(skip_live_purl: false)['Kurita']['release']).to be_truthy # we can still get the tags without going into an infinite loop
      end
    end
  end

  describe '#release_tags' do
    subject(:release_tags) { releases.release_tags }

    context 'for an item that does not have any release tags' do
      let(:item) { instantiate_fixture('druid:qv648vd4392', Dor::Item) }

      it { is_expected.to eq({}) }
    end

    it 'returns the releases for an item that has release tags' do
      exp_result = {
        'Revs' => [
          { 'tag' => 'true', 'what' => 'collection', 'when' => Time.parse('2015-01-06 23:33:47Z'), 'who' => 'carrickr', 'release' => true },
          { 'tag' => 'true', 'what' => 'self', 'when' => Time.parse('2015-01-06 23:33:54Z'), 'who' => 'carrickr', 'release' => true },
          { 'tag' => 'Project : Fitch : Batch2', 'what' => 'self', 'when' => Time.parse('2015-01-06 23:40:01Z'), 'who' => 'carrickr', 'release' => false }
        ]
      }
      expect(release_tags).to eq exp_result
    end
  end
end
