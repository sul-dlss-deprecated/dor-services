# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::ReleaseTags::IdentityMetadata do
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

    describe '#newest_release_tag_in_an_array' do
      subject { releases.send(:newest_release_tag_in_an_array, dummy_tags) }

      it { is_expected.to eq dummy_tags[1] }
    end

    describe '#newest_release_tag' do
      subject { releases.newest_release_tag(dummy_hash) }

      let(:dummy_hash) { { 'Revs' => dummy_tags, 'FRDA' => dummy_tags } }

      it { is_expected.to eq('Revs' => dummy_tags[1], 'FRDA' => dummy_tags[1]) }
    end

    describe '#latest_applicable_release_tag_in_array' do
      it 'returns nil when no tags apply' do
        expect(releases.send(:latest_applicable_release_tag_in_array, dummy_tags, bryar_trans_am_admin_tags)).to be_nil
      end

      it 'returns a tag when it does apply' do
        valid_tag = { 'when' => array_of_times[3], 'tag' => 'Project : Revs' }
        expect(releases.send(:latest_applicable_release_tag_in_array, dummy_tags << valid_tag, bryar_trans_am_admin_tags)).to eq(valid_tag)
      end

      it 'returns a valid tag even if there are non applicable older ones in front of it' do
        valid_tag = { 'when' => array_of_times[2], 'tag' => 'Project : Revs' }
        newer_no_op_tag = { 'when' => array_of_times[3], 'tag' => "Jim Harbaugh's Nonexistent Moments With The Raiders" }
        expect(releases.send(:latest_applicable_release_tag_in_array, dummy_tags + [valid_tag, newer_no_op_tag], bryar_trans_am_admin_tags)).to eq(valid_tag)
      end

      it 'returns the most recent tag when there are two valid tags' do
        valid_tag = { 'when' => array_of_times[2], 'tag' => 'Project : Revs' }
        newer_valid_tag = { 'when' => array_of_times[3], 'tag' => 'tag : test1' }
        expect(releases.send(:latest_applicable_release_tag_in_array, dummy_tags + [valid_tag, newer_valid_tag], bryar_trans_am_admin_tags)).to eq(newer_valid_tag)
      end
    end

    describe '#does_release_tag_apply' do
      it 'recognizes a release tag with no tag attribute applies' do
        local_dummy_tag = { 'when' => array_of_times[0], 'who' => 'carrickr' }
        expect(releases.send(:does_release_tag_apply, local_dummy_tag, bryar_trans_am_admin_tags)).to be_truthy
      end

      it 'does not require admin tags to be passed in' do
        local_dummy_tag = { 'when' => array_of_times[0], 'who' => 'carrickr' }
        expect(releases.send(:does_release_tag_apply, local_dummy_tag)).to be_truthy
        expect(releases.send(:does_release_tag_apply, dummy_tags[0])).to be_falsey
      end
    end

    describe '#tags_for_what_value' do
      it 'only returns tags for the specific what value' do
        expect(releases.send(:tags_for_what_value, { 'Revs' => dummy_tags }, 'self')).to eq('Revs' => [dummy_tags[0]])
        expect(releases.send(:tags_for_what_value, { 'Revs' => dummy_tags, 'FRDA' => dummy_tags }, 'collection')).to eq('Revs' => [dummy_tags[1]], 'FRDA' => [dummy_tags[1]])
      end
    end

    describe '#combine_two_release_tag_hashes' do
      it 'combines two hashes of tags without overwriting any data' do
        h_one = { 'Revs' => [dummy_tags[0]] }
        h_two = { 'Revs' => [dummy_tags[1]], 'FRDA' => dummy_tags }
        expected_result = { 'Revs' => dummy_tags, 'FRDA' => dummy_tags }
        expect(releases.send(:combine_two_release_tag_hashes, h_one, h_two)).to eq(expected_result)
      end
    end

    it 'only returns self release tags' do
      expect(releases.send(:self_release_tags, 'Revs' => dummy_tags, 'FRDA' => dummy_tags, 'BV' => [dummy_tags[1]])).to eq('Revs' => [dummy_tags[0]], 'FRDA' => [dummy_tags[0]])
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

  describe '#release_tag_node_to_hash' do
    it 'returns a hash created from a single release tag' do
      n = Nokogiri('<release to="Revs" what="collection" when="2015-01-06T23:33:47Z" who="carrickr">true</release>').xpath('//release')[0]
      exp_result = { to: 'Revs', attrs: { 'what' => 'collection', 'when' => Time.parse('2015-01-06 23:33:47Z'), 'who' => 'carrickr', 'release' => true } }
      expect(releases.send(:release_tag_node_to_hash, n)).to eq exp_result
      n = Nokogiri('<release tag="Project : Fitch: Batch1" to="Revs" what="collection" when="2015-01-06T23:33:47Z" who="carrickr">true</release>').xpath('//release')[0]
      exp_result = { to: 'Revs', attrs: { 'tag' => 'Project : Fitch: Batch1', 'what' => 'collection', 'when' => Time.parse('2015-01-06 23:33:47Z'), 'who' => 'carrickr', 'release' => true } }
      expect(releases.send(:release_tag_node_to_hash, n)).to eq exp_result
    end
  end

  describe '#release_tags_for_item_and_all_governing_sets' do
    let(:collection) { Dor::Collection.new }
    let(:collection_result) do
      {
        'Searchworks' => [
          { 'tag' => 'true', 'what' => 'collection', 'when' => Time.parse('2015-01-06 23:33:47Z'), 'who' => 'carrickr', 'release' => true }
        ]
      }
    end
    let(:collection_tags) { instance_double(described_class, release_tags_for_item_and_all_governing_sets: collection_result) }

    before do
      releases # call releases before subbing the invocation.
      allow(item).to receive(:collections).and_return([collection])
      allow(described_class).to receive(:for).with(collection).and_return(collection_tags)
    end

    it 'gets tags from collections and the item' do
      expect(releases.release_tags_for_item_and_all_governing_sets.keys).to include('Revs', 'Searchworks')
    end
  end
end
