# frozen_string_literal: true

require 'spec_helper'

class ReleaseableItem < ActiveFedora::Base
  include Dor::Releaseable
  include Dor::Governable
  include Dor::Identifiable
end

RSpec.describe Dor::Releaseable, :vcr do
  before do
    stub_config
  end

  after do
    Dor::Config.pop!
  end

  # Warning:  Exercise care when rerecording these cassette, as these items are set up to have specific tags on them at the time of recording.
  # Other folks messing around in the dev environment might add or remove release tags that cause failures on these tests.
  # TODO: rework all VCR recs into conventional fixtures or re-record them for AF6.
  # If these tests fail, check not just the logic, but also the specific tags
  describe 'handling tags on objects and determining release status' do
    it 'should use only the most recent self tag to determine if an item is released, with no release tags on the collection' do
      VCR.use_cassette('should_use_only_the_most_recent_self_tag_to_determine_if_an_item_is_released_with_no_release_tags_on_the_collection') do
        item = instantiate_fixture('druid:vs298kg2555', Dor::Item)
        expect(item.released_for['Kurita']['release']).to be_truthy
      end
    end

    it 'should deal with a bad collection record that references itself and not end up in an infinite loop by skipping the tag check for itself' do
      collection_druid = 'druid:wz243gf4151'
      collection = instantiate_fixture(collection_druid, Dor::Item)
      allow(collection).to receive(:collections).and_return([collection]) # force it to return itself as a member
      expect(collection.collections.first.id).to eq collection.id # confirm it is a member of itself
      expect(collection.released_for['Kurita']['release']).to be_truthy # we can still get the tags without going into an infinite loop
    end

    it 'merges tags' do
      item = instantiate_fixture('druid:vs298kg2555', Dor::Item)
      collection = instantiate_fixture('druid:wz243gf4151', Dor::Item)
      allow(item).to receive(:collections).and_return([collection]) # force it to return itself as a member
      expect(item.released_for['Kurita']['release']).to be_truthy # we can still get the tags without going into an infinite loop
    end

    # This test takes an object with a self tag that is older and opposite the tag on this object's collection and ensures the self tag still is the one that is used to decide release status
    it 'should use the self tag over the collection tag to determine if an item is released, even if the collection tag is newer' do
      skip 'VCR cassette recorded on only one (old) version of ActiveFedora.  Stub methods or record on both AF5 and AF6'
      VCR.use_cassette('releaseable_self_over_collection') do
        item = Dor::Item.find('druid:bb537hc4022')
        expect(item.released_for['Kurita']['release']).to be_falsey
      end
    end

    # This test looks at an item whose only tags are on the collection and ensures the most recent one wins
    it 'should use only most the recent collection tag if no self tags are present' do
      skip 'VCR cassette recorded on only one (old) version of ActiveFedora.  Stub methods or record on both AF5 and AF6'
      VCR.use_cassette('releaseable_most_recent_collection_tag_wins') do
        item = Dor::Item.find('druid:bc566xq6031')
        expect(item.release_tags).to eq({})
        expect(item.released_for['Kurita']['release']).to be_truthy
      end
    end

    # A collection whose only tag is to release a what=collection should also release the collection object itself
    it 'a tag with what=collection should release the collection item, assuming it is not blocked by a self tag' do
      skip 'VCR cassette recorded on only one (old) version of ActiveFedora.  Stub methods or record on both AF5 and AF6'
      VCR.use_cassette('releaseable_collection_tag_releases_collection_object') do
        item = Dor::Item.find('druid:wz243gf4151')
        expect(item.released_for['Kurita']['release']).to be_truthy
      end
    end

    # Here we have an object governed by both the Marcus Chambers, druid:wz243gf4151, Collection and the Revs Collection, druid:nt028fd5773
    # When determining if an item is released, it should look at both collections and pick the most recent timestamp
    it 'should look all collections and sets that an item is a member of' do
      skip 'VCR cassette recorded on only one (old) version of ActiveFedora.  Stub methods or record on both AF5 and AF6'
      VCR.use_cassette('releaseable_multiple_collections') do
        item = Dor::Item.find('druid:dc235vd9662')
        expect(item.released_for['Atago']['release']).to be_truthy
        chambers_collection = Dor::Item.find('druid:wz243gf4151')
        expect(chambers_collection.release_tags['Atago']).to eq [{ 'what' => 'collection', 'who' => 'carrickr', 'when' => Time.parse('2015-01-21 22:37:21Z').iso8601, 'release' => true }]
        revs_collection = Dor::Item.find('druid:nt028fd5773')
        expect(revs_collection.release_tags['Atago']).to eq([{ 'what' => 'collection', 'who' => 'carrickr', 'when' => Time.parse('2015-01-21 22:37:40Z').iso8601, 'release' => false }])
      end
    end

    # If an items release is controlled with the tag= attr, meaning that only items with that administrative tag are released, that should be respected
    it 'should respect the tag= attr and apply it when releasing' do
      skip 'VCR cassette recorded on only one (old) version of ActiveFedora.  Stub methods or record on both AF5 and AF6'
      VCR.use_cassette('releaseable_respect_admin_tagging') do
        chambers_collection = Dor::Item.find('druid:wz243gf4151')
        exp_result = [{ 'what' => 'collection', 'who' => 'carrickr', 'tag' => 'Project : ReleaseSpecTesting : Batch1', 'when' => Time.parse('2015-01-21 22:46:22Z').iso8601, 'release' => true }]
        expect(chambers_collection.release_tags['Mogami']).to eq exp_result
        item_with_this_admin_tag = Dor::Item.find('druid:dc235vd9662')
        expect(item_with_this_admin_tag.tags).to include 'Project : ReleaseSpecTesting : Batch1'
        expect(item_with_this_admin_tag.released_for['Mogami']['release']).to be_truthy
        item_without_this_admin_tag = Dor::Item.find('druid:bc566xq6031')
        expect(item_without_this_admin_tag.tags).not_to include('Project : ReleaseSpecTesting : Batch1')
        expect(item_without_this_admin_tag.released_for['Mogami']).to be_nil
      end
    end

    it 'should return release xml for an item as string of elements wrapped in a ReleaseDigestRoot' do
      skip 'VCR cassette recorded on only one (old) version of ActiveFedora.  Stub methods or record on both AF5 and AF6'
      VCR.use_cassette('releaseable_release_xml') do
        item = Dor::Item.find('druid:dc235vd9662')
        release_xml = item.generate_release_xml
        expect(release_xml).to be_a(String)
        true_or_false = %w(true false)
        xml_obj = Nokogiri(release_xml)
        xml_obj.xpath('//release').each do |release_node|
          expect(release_node.name).to eq('release') # Well, duh
          expect(release_node.attributes.keys).to eq(['to'])
          expect(release_node.attributes['to'].value).to be_a(String)
          expect(true_or_false.include?(release_node.children.text)).to be_truthy
        end
      end
    end
  end
end

RSpec.describe 'Adding release nodes', :vcr do
  let(:item) { instantiate_fixture('druid:bb004bn8654', Dor::Item) }

  before do
    stub_config
  end

  after do
    Dor::Config.pop!
  end

  describe '#release_tags' do
    subject(:release_tags) { item.release_tags }
    let(:service) { instance_double(Dor::ReleaseTagService, release_tags: ['foo']) }

    before do
      allow(Dor::ReleaseTagService).to receive(:for).with(item).and_return(service)
    end

    it 'delegates to the service' do
      expect(Deprecation).to receive(:warn)
      expect(release_tags).to eq ['foo']
    end
  end

  describe '#get_newest_release_tag' do
    subject(:get_newest_release_tag) { item.get_newest_release_tag('Revs' => %w[foo bar], 'FRDA' => %w[quax qwerk]) }
    let(:service) { instance_double(Dor::ReleaseTagService, newest_release_tag: { 'Revs' => 'foo', 'FRDA' => 'qwerk' }) }

    before do
      allow(Dor::ReleaseTagService).to receive(:for).with(item).and_return(service)
    end

    it 'delegates to the service' do
      expect(Deprecation).to receive(:warn)
      expect(get_newest_release_tag).to eq('FRDA' => 'qwerk', 'Revs' => 'foo')
    end
  end

  describe 'Adding tags and workflows' do
    before do
      expect(Deprecation).to receive(:warn)
    end
    it 'should release an item with one release tag supplied' do
      allow(item).to receive(:save).and_return(true) # stud out the true in that it we lack a connection to solr
      expect(item).to receive(:create_workflow).with('releaseWF') # Make sure releaseWF is called
      expect(item).to receive(:add_release_node).once
      expect(item.add_release_nodes_and_start_releaseWF(release: true, what: 'self', who: 'carrickr', to: 'FRDA')).to eq(nil) # Should run and return void
    end
    it 'should release an item with multiple release tags supplied' do
      allow(item).to receive(:save).and_return(true) # stud out the true in that it we lack a connection to solr
      expect(item).to receive(:create_workflow).with('releaseWF') # Make sure releaseWF is called
      expect(item).to receive(:add_release_node).twice
      tags = [{ release: true, what: 'self', who: 'carrickr', to: 'FRDA' }, { release: true, what: 'self', who: 'carrickr', to: 'Revs' }]
      expect(item.add_release_nodes_and_start_releaseWF(tags)).to eq(nil) # Should run and return void
    end
  end

  describe 'valid_release_attributes' do
    before do
      allow(Deprecation).to receive(:warn)
      @args = { when: '2015-01-05T23:23:45Z', who: 'carrickr', to: 'Revs', what: 'collection', tag: 'Project:Fitch:Batch2' }
    end

    it 'should raise an error when :who, :to, :what are missing or are not strings' do
      expect{ item.valid_release_attributes(true,  @args.merge(who: nil)) }.to raise_error(ArgumentError)
      expect{ item.valid_release_attributes(false, @args.merge(to: nil)) }.to raise_error(ArgumentError)
      expect{ item.valid_release_attributes(true,  @args.merge(what: nil)) }.to raise_error(ArgumentError)
      expect{ item.valid_release_attributes(true,  @args.merge(who: 1)) }.to raise_error(ArgumentError)
      expect{ item.valid_release_attributes(true,  @args.merge(to: true)) }.to raise_error(ArgumentError)
      expect{ item.valid_release_attributes(false, @args.merge(what: %w(i am an array))) }.to raise_error(ArgumentError)
    end
    it 'should not raise an error when :what is self or collection' do
      expect(item.valid_release_attributes(false, @args)).to be true
      expect(item.valid_release_attributes(true,  @args.merge(what: 'self'))).to be true
    end
    it 'raises an argument error when :what is a string, but is not self or collection' do
      expect{ item.valid_release_attributes(true, @args.merge(what: 'foo')) }.to raise_error(ArgumentError)
    end
    it 'should add a tag when all attributes are properly provided, and drop the invalid <tag> attribute' do
      VCR.use_cassette('simple_release_tag_add_success_test') do
        tag_xml = item.add_release_node(true, @args.merge(what: 'self'))
        expect(tag_xml).to be_a_kind_of(Nokogiri::XML::Element)
        expect(tag_xml.to_xml).to eq('<release when="2015-01-05T23:23:45Z" who="carrickr" to="Revs" what="self">true</release>')
      end
    end
    it 'should fail to add a release node when there is an attribute error' do
      VCR.use_cassette('simple_release_tag_add_success_test') do
        expect{ item.add_release_node(true,  who: nil, to: 'Revs', what: 'self') }.to raise_error(ArgumentError) # who is not a string
        expect{ item.add_release_node(true,  who: nil, to: 'Revs', what: 'unknown_value') }.to raise_error(ArgumentError) # who is not a string
        expect{ item.add_release_node(1, @args) }.to raise_error(ArgumentError) # invalid release value
      end
    end
    it 'should drop all invalid attributes passed in' do
      VCR.use_cassette('simple_release_tag_add_success_test') do
        new_tag = '<release when="2016-01-05T23:23:45Z" who="petucket" to="Revs" what="self">true</release>'
        expect(item.identityMetadata.to_xml).to_not include new_tag
        item.add_release_node(true, :when => '2016-01-05T23:23:45Z', :who => 'petucket', :to => 'Revs', :what => 'self', :blop => 'something', :tag => 'Revs', 'something_else' => 'whatup')
        expect(item.identityMetadata.to_xml).to include new_tag
      end
    end
    it 'should return true when valid_release_attributes is called with valid attributes and no tag attribute' do
      @args.delete :tag
      expect(item.valid_release_attributes(true, @args)).to be true
    end
    it 'should return true when valid_release_attributes is called with valid attributes and tag attribute' do
      expect(item.valid_release_attributes(true, @args)).to be true
    end
    it 'should raise an error when valid_release_attributes is called with a tag content that is not a boolean' do
      expect{ item.valid_release_attributes(1, @args) }.to raise_error(ArgumentError)
    end
  end
end
