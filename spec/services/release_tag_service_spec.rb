# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::ReleaseTagService do
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

  describe '#add_tags_from_purl' do
    let(:xml) { Nokogiri::XML(response) }

    context 'for targets that are listed on the purl but not in new tag generation' do
      let(:le_mans_druid) { 'druid:dc235vd9662' }
      let(:item) { instantiate_fixture(le_mans_druid, Dor::Item) }
      let(:response) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <publicObject id="druid:dc235vd9662" published="2015-02-05T11:09:34-08:00">
            <identityMetadata>
              <sourceId source="Revs">2011-023CHAM-1.0_0001</sourceId>
              <objectId>druid:dc235vd9662</objectId>
              <objectCreator>DOR</objectCreator>
              <objectLabel>Le Mans, 1955 ; Mille Miglia 1956</objectLabel>
              <objectType>item</objectType>
              <adminPolicy>druid:qv648vd4392</adminPolicy>
              <otherId name="uuid">f36fcad6-955f-11e1-9027-0050569b52c6</otherId>
              <tag>Project : Revs</tag>
              <tag>Project : ReleaseSpecTesting : Batch1</tag>
              <release to="Kurita">true</release>
              <release to="Atago">false</release>
              <release to="Mogami">true</release>
            </identityMetadata>
            <contentMetadata objectId="dc235vd9662" type="image">
              <resource sequence="1" id="dc235vd9662_1" type="image">
                <label>Item 1</label>
                <file id="2011-023Cham-1.0_0001.jp2" mimetype="image/jp2" size="1965344">
                  <imageData width="4004" height="2600"/>
                </file>
              </resource>
            </contentMetadata>
            <rightsMetadata>
              <copyright>
                <human type="copyright">Courtesy of Collier Collection. All rights reserved unless otherwise indicated.</human>
              </copyright>
              <access type="discover">
                <machine>
                  <world/>
                </machine>
              </access>
              <access type="read">
                <machine>
                  <group>stanford</group>
                </machine>
              </access>
              <use>
                <human type="useAndReproduction">Users must contact the The Revs Institute for Automobile Research for re-use and reproduction information.</human>
              </use>
            </rightsMetadata>
            <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
              <rdf:Description rdf:about="info:fedora/druid:dc235vd9662">
                <fedora:isMemberOf rdf:resource="info:fedora/druid:wz243gf4151"/>
                <fedora:isMemberOf rdf:resource="info:fedora/druid:wz243gf4151"/>
                <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:wz243gf4151"/>
              </rdf:Description>
            </rdf:RDF>
            <oai_dc:dc xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:srw_dc="info:srw/schema/1/dc-schema" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
              <dc:type>StillImage</dc:type>
              <dc:type>digital image</dc:type>
              <dc:subject>Automobile--History</dc:subject>
              <dc:date>1955 , 1956</dc:date>
              <dc:title>Le Mans, 1955 ; Mille Miglia 1956</dc:title>
              <dc:identifier>2011-023CHAM-1.0_0001</dc:identifier>
              <dc:relation type="collection">The Marcus Chambers Collection of the Revs Institute</dc:relation>
            </oai_dc:dc>
            <releaseData>
              <release to="Kurita">true</release>
              <release to="Atago">false</release>
              <release to="Mogami">true</release>
            </releaseData>
          </publicObject>
        XML
      end

      let(:client) { instance_double(Dor::PurlClient, fetch: xml) }

      before do
        allow(Dor::PurlClient).to receive(:new).and_return(client)
        # stub_request(:get, 'https://purl-test.stanford.edu/dc235vd9662.xml')
        #   .to_return(status: 200, body: response)
      end

      it 'adds in release tags as false' do
        generated_tags = {} # pretend no tags were found in the most recent dor object, so all tags in the purl returns false
        tags_currently_in_purl = releases.send(:release_tags_from_purl_xml, xml) # These are the tags currently in purl
        final_result_tags = releases.send(:add_tags_from_purl, generated_tags) # Final result of dor and purl tags
        expect(final_result_tags.keys).to match(tags_currently_in_purl) # all tags currently in purl should be reflected
        final_result_tags.keys.each do |tag|
          expect(final_result_tags[tag]).to match('release' => false) # all tags should be false for their releas
        end
      end

      it 'adds in release tags as false' do
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
