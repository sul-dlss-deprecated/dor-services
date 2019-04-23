# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::PublishedRelationshipsFilter do
  subject(:service) { described_class.new(obj) }

  let(:obj) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }

  describe '#xml' do
    subject(:doc) { service.xml }

    context 'with isMemberOfCollection and isConstituentOf relationships' do
      let(:relationships) do
        <<~EOXML
          <rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:hydra="http://projecthydra.org/ns/relations#">
            <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
              <hydra:isGovernedBy rdf:resource="info:fedora/druid:789012"></hydra:isGovernedBy>
              <fedora-model:hasModel rdf:resource="info:fedora/hydra:commonMetadata"></fedora-model:hasModel>
              <fedora:isMemberOf rdf:resource="info:fedora/druid:xh235dd9059"></fedora:isMemberOf>
              <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:xh235dd9059"></fedora:isMemberOfCollection>
              <fedora:isConstituentOf rdf:resource="info:fedora/druid:hj097bm8879"></fedora:isConstituentOf>
            </rdf:Description>
          </rdf:RDF>
        EOXML
      end

      before do
        ActiveFedora::RelsExtDatastream.from_xml(relationships, obj.rels_ext)
        # Needed to generate the Datastream#content
        obj.object_relations.dirty = true
        obj.rels_ext.serialize!
      end

      it 'discards the non-allowed relations' do
        expect(doc).to be_equivalent_to <<~XML
          <?xml version="1.0"?>
            <rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:hydra="http://projecthydra.org/ns/relations#">
              <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
                <fedora:isMemberOf rdf:resource="info:fedora/druid:xh235dd9059"/>
                <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:xh235dd9059"/>
                <fedora:isConstituentOf rdf:resource="info:fedora/druid:hj097bm8879"/>
              </rdf:Description>
            </rdf:RDF>
        XML
      end
    end
  end
end
