require 'spec_helper'

RSpec.describe Dor::IdentifiableIndexer do
  let(:model) do
    Class.new(Dor::Abstract) do
      include Dor::Identifiable
      def self.name
        'foo'
      end
    end
  end
  before { stub_config }
  after { unstub_config }

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
      obj.remove_other_Id('catkey', '129483625')
      obj.remove_other_Id('barcode', '36105049267078')
      obj.add_other_Id('catkey', '129483625')
      expect(indexer.identity_metadata_source).to eq 'Symphony'
      obj.remove_other_Id('catkey', '129483625')
      obj.add_other_Id('barcode', '36105049267078')
      expect(indexer.identity_metadata_source).to eq 'Symphony'
      obj.remove_other_Id('barcode', '36105049267078')
      expect(indexer.identity_metadata_source).to eq 'DOR'
      obj.remove_other_Id('foo', 'bar')
      expect(indexer.identity_metadata_source).to eq 'DOR'
    end

    it 'indexes metadata source' do
      expect(indexer.identity_metadata_source).to eq 'Symphony'
    end
  end

  describe '#to_solr' do
    let(:doc) { indexer.to_solr }
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

    it 'generate collections and apo title fields' do
      allow(obj.datastreams['RELS-EXT']).to receive(:content).and_return(mock_rels_ext_xml)
      allow(Dor).to receive(:find).with(mock_rel_druid).and_raise(ActiveFedora::ObjectNotFoundError)

      ['apo_title', 'nonhydrus_apo_title'].each do |field_name|
        expect(doc[Solrizer.solr_name(field_name, :symbol)].first).to eq(mock_rel_druid)
        expect(doc[Solrizer.solr_name(field_name, :stored_searchable)].first).to eq(mock_rel_druid)
      end
    end

    it 'indexes metadata source' do
      expect(doc).to match a_hash_including('metadata_source_ssi' => 'Symphony')
    end

    it 'generates set collection and apo fields to the druid if the collection or apo does not exist' do
      allow(obj.datastreams['RELS-EXT']).to receive(:content).and_return(mock_rels_ext_xml)
      allow(Dor).to receive(:find).with(mock_rel_druid).and_raise(ActiveFedora::ObjectNotFoundError)

      ['apo_title', 'collection_title'].each do |field_name|
        expect(doc[Solrizer.solr_name(field_name, :symbol)].first).to eq(mock_rel_druid)
        expect(doc[Solrizer.solr_name(field_name, :stored_searchable)].first).to eq(mock_rel_druid)
      end
    end
  end
end
