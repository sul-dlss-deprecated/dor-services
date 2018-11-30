# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::ReleaseTagService, :vcr do
  before { stub_config }
  after { Dor::Config.pop! }

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

      it 'returns the latest tag for each key/target in a hash' do
        dummy_hash = { 'Revs' => dummy_tags, 'FRDA' => dummy_tags }
        expect(releases.send(:newest_release_tag, dummy_hash)).to eq('Revs' => dummy_tags[1], 'FRDA' => dummy_tags[1])
      end
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

    describe '.combine_two_release_tag_hashes' do
      it 'combines two hashes of tags without overwriting any data' do
        h_one = { 'Revs' => [dummy_tags[0]] }
        h_two = { 'Revs' => [dummy_tags[1]], 'FRDA' => dummy_tags }
        expected_result = { 'Revs' => dummy_tags, 'FRDA' => dummy_tags }
        expect(described_class.send(:combine_two_release_tag_hashes, h_one, h_two)).to eq(expected_result)
      end
    end

    it 'only returns self release tags' do
      expect(releases.send(:self_release_tags, 'Revs' => dummy_tags, 'FRDA' => dummy_tags, 'BV' => [dummy_tags[1]])).to eq('Revs' => [dummy_tags[0]], 'FRDA' => [dummy_tags[0]])
    end
  end

  # Warning:  Exercise care when rerecording these cassette, as these items are set up to have specific tags on them at the time of recording.
  # Other folks messing around in the dev environment might add or remove release tags that cause failures on these tests.
  # TODO: rework all VCR recs into conventional fixtures or re-record them for AF6.
  # If these tests fail, check not just the logic, but also the specific tags
  describe 'handling tags on objects and determining release status' do
    let(:item) { instantiate_fixture('druid:vs298kg2555', Dor::Item) }
    it 'uses only the most recent self tag to determine if an item is released, with no release tags on the collection' do
      VCR.use_cassette('should_use_only_the_most_recent_self_tag_to_determine_if_an_item_is_released_with_no_release_tags_on_the_collection') do
        expect(releases.released_for(skip_live_purl: false)['Kurita']['release']).to be_truthy
      end
    end

    context 'with a bad collection record that references itself' do
      let(:item) { instantiate_fixture('druid:wz243gf4151', Dor::Item) }

      it 'does not end up in an infinite loop by skipping the tag check for itself' do
        allow(item).to receive(:collections).and_return([item]) # force it to return itself as a member
        expect(item.collections.first.id).to eq item.id # confirm it is a member of itself
        expect(releases.released_for(skip_live_purl: false)['Kurita']['release']).to be_truthy # we can still get the tags without going into an infinite loop
      end
    end
  end

  describe '#release_nodes' do
    subject(:release_nodes) { releases.send(:release_nodes) }

    context 'for an item that does not have any release nodes' do
      let(:item) { instantiate_fixture('druid:qv648vd4392', Dor::Item) }

      it { is_expected.to eq({}) }
    end

    it 'returns the releases for an item that has release tags' do
      exp_result = { 'Revs' => [
        { 'tag' => 'true', 'what' => 'collection', 'when' => Time.parse('2015-01-06 23:33:47Z'), 'who' => 'carrickr', 'release' => true },
        { 'tag' => 'true', 'what' => 'self', 'when' => Time.parse('2015-01-06 23:33:54Z'), 'who' => 'carrickr', 'release' => true },
        { 'tag' => 'Project : Fitch : Batch2', 'what' => 'self', 'when' => Time.parse('2015-01-06 23:40:01Z'), 'who' => 'carrickr', 'release' => false }
      ] }
      expect(release_nodes).to eq exp_result
    end
  end

  it 'returns a hash created from a single release tag' do
    n = Nokogiri('<release to="Revs" what="collection" when="2015-01-06T23:33:47Z" who="carrickr">true</release>').xpath('//release')[0]
    exp_result = { :to => 'Revs', :attrs => { 'what' => 'collection', 'when' => Time.parse('2015-01-06 23:33:47Z'), 'who' => 'carrickr', 'release' => true } }
    expect(releases.send(:release_tag_node_to_hash, n)).to eq exp_result
    n = Nokogiri('<release tag="Project : Fitch: Batch1" to="Revs" what="collection" when="2015-01-06T23:33:47Z" who="carrickr">true</release>').xpath('//release')[0]
    exp_result = { :to => 'Revs', :attrs => { 'tag' => 'Project : Fitch: Batch1', 'what' => 'collection', 'when' => Time.parse('2015-01-06 23:33:47Z'), 'who' => 'carrickr', 'release' => true } }
    expect(releases.send(:release_tag_node_to_hash, n)).to eq exp_result
  end

  describe '#form_purl_url' do
    subject { releases.send(:form_purl_url) }
    it { is_expected.to eq "https://#{Dor::Config.stacks.document_cache_host}/bb004bn8654.xml" }
  end

  describe '#xml_from_purl' do
    subject(:xml) { releases.send(:xml_from_purl) }

    it 'gets the purl xml for a druid' do
      VCR.use_cassette('fetch_purl_test_xml') do
        expect(xml).to be_a(Nokogiri::HTML::Document)
        expect(xml.at_xpath('//html/body/publicobject').attr('id')).to eq(item.id)
      end
    end

    it 'does not raise an error for a 404 when attempted to obtain a purl' do
      VCR.use_cassette('purl_404') do
        expect(Dor.logger).to receive(:warn).once
        expect(item).to receive(:id).and_return('druid:IAmABadDruid').at_least(:once)
        expect(xml).to be_a(Nokogiri::HTML::Document)
      end
    end

    context 'for targets that are listed on the purl but not in new tag generation' do
      let(:le_mans_druid) { 'druid:dc235vd9662' }
      let(:item) { instantiate_fixture(le_mans_druid, Dor::Item) }

      it 'adds in release tags as false' do
        VCR.use_cassette('fetch_le_mans_purl') do
          generated_tags = {} # pretend no tags were found in the most recent dor object, so all tags in the purl returns false
          tags_currently_in_purl = releases.send(:release_tags_from_purl_xml, xml) # These are the tags currently in purl
          final_result_tags = releases.send(:add_tags_from_purl, generated_tags) # Final result of dor and purl tags
          expect(final_result_tags.keys).to match(tags_currently_in_purl) # all tags currently in purl should be reflected
          final_result_tags.keys.each do |tag|
            expect(final_result_tags[tag]).to match('release' => false) # all tags should be false for their releas
          end
        end
      end

      it 'adds in release tags as false' do
        VCR.use_cassette('fetch_le_mans_purl') do
          generated_tags = { 'Kurita' => { 'release' => true } } # only kurita has returned as true
          tags_currently_in_purl = releases.send(:release_tags_from_purl_xml, xml) # These are the tags currently in purl
          final_result_tags = releases.send(:add_tags_from_purl, generated_tags) # Final result of dor and purl tags
          expect(final_result_tags.keys).to match(tags_currently_in_purl) # all tags currently in purl should be reflected
          final_result_tags.keys.each do |tag|
            expect(final_result_tags[tag]).to match('release' => false) if tag != 'Kurita' # Kurita should still be true
          end
          expect(final_result_tags['Kurita']).to match('release' => true)
        end
      end
    end
  end
end
