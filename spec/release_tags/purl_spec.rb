# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::ReleaseTags::Purl do
  let(:druid) { 'druid:bb004bn8654' }
  let(:releases) { described_class.new(pid: druid, purl_host: 'purl-test.stanford.edu') }

  describe '#released_for' do
    before do
      allow(Deprecation).to receive(:warn)
    end

    let(:xml) { Nokogiri::XML(response) }

    context 'for targets that are listed on the purl but not in new tag generation' do
      let(:druid) { 'druid:dc235vd9662' }

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

      let(:client) { instance_double(Dor::ReleaseTags::PurlClient, fetch: xml) }

      before do
        allow(Dor::ReleaseTags::PurlClient).to receive(:new).and_return(client)
      end

      it 'adds in release tags as false' do
        generated_tags = {} # pretend no tags were found in the most recent dor object, so all tags in the purl returns false
        tags_currently_in_purl = releases.send(:release_tags_from_purl_xml, xml) # These are the tags currently in purl
        final_result_tags = releases.released_for(generated_tags) # Final result of dor and purl tags
        expect(final_result_tags.keys).to match(tags_currently_in_purl) # all tags currently in purl should be reflected
        final_result_tags.keys.each do |tag|
          expect(final_result_tags[tag]).to match('release' => false) # all tags should be false for their releas
        end
      end

      it 'adds in release tags as false' do
        generated_tags = { 'Kurita' => { 'release' => true } } # only kurita has returned as true
        tags_currently_in_purl = releases.send(:release_tags_from_purl_xml, xml) # These are the tags currently in purl
        final_result_tags = releases.released_for(generated_tags) # Final result of dor and purl tags
        expect(final_result_tags.keys).to match(tags_currently_in_purl) # all tags currently in purl should be reflected
        final_result_tags.keys.each do |tag|
          expect(final_result_tags[tag]).to match('release' => false) if tag != 'Kurita' # Kurita should still be true
        end
        expect(final_result_tags['Kurita']).to match('release' => true)
      end
    end
  end
end
