# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::CollectionService do
  let(:item) { instantiate_fixture('druid:oo201oo0001', Dor::AdminPolicyObject) }
  let(:service) { described_class.new(item) }
  let(:collection_id) { 'druid:oo201oo0002' }
  let(:collection) { Dor::Collection.new(pid: collection_id) }

  before do
    allow(collection).to receive(:new_record?).and_return false
    allow(Dor::Collection).to receive(:find).with(collection_id).and_return(collection)
  end

  describe '#add' do
    subject(:add) { service.add(collection_id) }

    it 'adds a collection to collection_ids' do
      add
      expect(item.collection_ids).to include(collection_id)
    end

    it 'adds a collection to the datastream xml' do
      add
      rels_ext_ds = item.datastreams['RELS-EXT']
      xml = Nokogiri::XML(rels_ext_ds.to_rels_ext.to_s)
      expect(xml).to be_equivalent_to <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#">
       <rdf:Description rdf:about="info:fedora/druid:oo201oo0001">
         <hydra:isGovernedBy rdf:resource="info:fedora/druid:fg890hi1234"/>
         <fedora-model:hasModel rdf:resource="info:fedora/afmodel:Hydrus_Item"/>
         <fedora:isMemberOf rdf:resource="info:fedora/druid:oo201oo0002"/>
         <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:oo201oo0002"/>
       </rdf:Description>
      </rdf:RDF>
      XML
    end
  end

  describe '#remove' do
    subject(:remove) { service.remove(collection_id) }

    before do
      service.add(collection_id)
    end

    it 'deletes a collection from collection_ids' do
      remove
      expect(item.collection_ids).not_to include(collection_id)
    end

    it 'deletes a collection from the datastream XML' do
      rels_ext_ds = item.datastreams['RELS-EXT']
      remove
      rels_ext_ds.serialize!
      xml = Nokogiri::XML(rels_ext_ds.content.to_s)
      expect(xml).to be_equivalent_to <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#">
        <rdf:Description rdf:about="info:fedora/druid:oo201oo0001">
          <hydra:isGovernedBy rdf:resource="info:fedora/druid:fg890hi1234"/>
          <fedora-model:hasModel rdf:resource="info:fedora/afmodel:Hydrus_Item"/>
        </rdf:Description>
      </rdf:RDF>
      XML
    end
  end
end
