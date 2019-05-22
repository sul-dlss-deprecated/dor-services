# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::IdentifiableIndexer do
  let(:model) do
    Class.new(Dor::Abstract) do
      def self.name
        'foo'
      end
    end
  end
  before do
    stub_config
    described_class.reset_cache!
  end

  let(:obj) do
    item = instantiate_fixture('druid:ab123cd4567', model)
    allow(item).to receive(:new?).and_return(false)
    ds = item.identityMetadata
    ds.instance_variable_set(:@datastream_content, item.identityMetadata.content)
    allow(ds).to receive(:new?).and_return(false)
    item
  end

  let(:indexer) do
    described_class.new(resource: obj)
  end

  describe '#identity_metadata_source' do
    it 'depends on remove_other_Id' do
      obj.identityMetadata.remove_other_Id('catkey', '129483625')
      obj.identityMetadata.remove_other_Id('barcode', '36105049267078')
      obj.identityMetadata.add_other_Id('catkey', '129483625')
      expect(indexer.identity_metadata_source).to eq 'Symphony'
      obj.identityMetadata.remove_other_Id('catkey', '129483625')
      obj.identityMetadata.add_other_Id('barcode', '36105049267078')
      expect(indexer.identity_metadata_source).to eq 'Symphony'
      obj.identityMetadata.remove_other_Id('barcode', '36105049267078')
      expect(indexer.identity_metadata_source).to eq 'DOR'
      obj.identityMetadata.remove_other_Id('foo', 'bar')
      expect(indexer.identity_metadata_source).to eq 'DOR'
    end

    it 'indexes metadata source' do
      expect(indexer.identity_metadata_source).to eq 'Symphony'
    end
  end

  describe '#to_solr' do
    let(:doc) { indexer.to_solr }

    context 'with related objects' do
      let(:mock_rel_druid) { 'druid:does_not_exist' }
      let(:mock_rels_ext_xml) do
        %(<rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
              xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:hydra="http://projecthydra.org/ns/relations#">
              <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
                <fedora-model:hasModel rdf:resource="info:fedora/testObject"/>
                <hydra:isGovernedBy rdf:resource="info:fedora/#{mock_rel_druid}"/>
                <fedora:isMemberOfCollection rdf:resource="info:fedora/#{mock_rel_druid}"/>
              </rdf:Description>
            </rdf:RDF>)
      end

      before do
        allow(obj.datastreams['RELS-EXT']).to receive(:content).and_return(mock_rels_ext_xml)
      end

      context 'when related collection and APOs are not found' do
        before do
          allow(Dor).to receive(:find).with(mock_rel_druid).and_raise(ActiveFedora::ObjectNotFoundError)
        end

        it 'generate collections and apo title fields' do
          expect(doc[Solrizer.solr_name('collection_title', :symbol)].first).to eq mock_rel_druid
          expect(doc[Solrizer.solr_name('collection_title', :stored_searchable)].first).to eq mock_rel_druid
          expect(doc[Solrizer.solr_name('apo_title', :symbol)].first).to eq mock_rel_druid
          expect(doc[Solrizer.solr_name('apo_title', :stored_searchable)].first).to eq mock_rel_druid
          expect(doc[Solrizer.solr_name('nonhydrus_apo_title', :symbol)].first).to eq mock_rel_druid
          expect(doc[Solrizer.solr_name('nonhydrus_apo_title', :stored_searchable)].first).to eq mock_rel_druid
        end
      end

      context 'when related collection and APOs are found' do
        let(:mock_obj) { instance_double(Dor::Item, full_title: 'Test object', tags: '') }

        before do
          allow(Dor).to receive(:find).with(mock_rel_druid).and_return(mock_obj)
        end

        it 'generate collections and apo title fields' do
          expect(doc[Solrizer.solr_name('collection_title', :symbol)].first).to eq 'Test object'
          expect(doc[Solrizer.solr_name('collection_title', :stored_searchable)].first).to eq 'Test object'
          expect(doc[Solrizer.solr_name('apo_title', :symbol)].first).to eq 'Test object'
          expect(doc[Solrizer.solr_name('apo_title', :stored_searchable)].first).to eq 'Test object'
          expect(doc[Solrizer.solr_name('nonhydrus_apo_title', :symbol)].first).to eq 'Test object'
          expect(doc[Solrizer.solr_name('nonhydrus_apo_title', :stored_searchable)].first).to eq  'Test object'
        end
      end
    end

    it 'indexes metadata source' do
      expect(doc).to match a_hash_including('metadata_source_ssi' => 'Symphony')
    end
  end

  describe '#related_obj_display_title' do
    subject { indexer.send(:related_obj_display_title, mock_apo_obj, mock_default_title) }

    let(:mock_default_title) { 'druid:zy098xw7654' }

    context 'when the main title is available' do
      let(:mock_apo_obj) { double(Dor::AdminPolicyObject, full_title: 'apo title') }

      it { is_expected.to eq 'apo title' }
    end

    context 'when the first descMetadata main title entry is empty string' do
      let(:mock_apo_obj) { double(Dor::AdminPolicyObject, full_title: nil) }

      it { is_expected.to eq mock_default_title }
    end

    context 'when the related object is nil' do
      let(:mock_apo_obj) { nil }

      it { is_expected.to eq mock_default_title }
    end
  end
end
