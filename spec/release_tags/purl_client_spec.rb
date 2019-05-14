# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::ReleaseTags::PurlClient do
  let(:client) do
    described_class.new(pid: pid,
                        host: 'purl-test.stanford.edu')
  end
  let(:pid) { 'druid:bb004bn8654' }

  describe '#url' do
    subject { client.send(:url) }

    it { is_expected.to eq 'https://purl-test.stanford.edu/bb004bn8654.xml' }
  end

  describe '#fetch' do
    subject(:xml) { client.send(:fetch) }

    context 'when the response is successful' do
      let(:response) do
        <<~XML
          <publicObject id="druid:bb004bn8654" published="2014-06-30T11:38:34-07:00">
              <identityMetadata>
                <sourceId source="Revs">2012-027NADI-1966-b1_4.3_0015</sourceId>
                <objectId>druid:bb004bn8654</objectId>
                <objectCreator>DOR</objectCreator>
                <objectLabel>Bryar 250 Trans-American: July 9-10</objectLabel>
                <objectType>item</objectType>
                <adminPolicy>druid:qv648vd4392</adminPolicy>
                <otherId name="uuid">e96fdf84-5c43-11e2-a99a-0050569b52d5</otherId>
                <tag>Project : Revs</tag>
                <tag>Remediated By : 3.25.0</tag>
              </identityMetadata>
              <contentMetadata type="image" objectId="bb004bn8654">
                <resource type="image" sequence="1" id="bb004bn8654_1">
                  <label>Image 1</label>
                  <file id="2012-027NADI-1966-b1_4.3_0015.jp2" mimetype="image/jp2" size="2006651">
                    <imageData width="4000" height="2659"/>
                  </file>
                </resource>
              </contentMetadata>
              <rightsMetadata>
                <copyright>
                  <human type="copyright">Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.</human>
                </copyright>
                <access type="discover">
                  <machine>
                    <world/>
                  </machine>
                </access>
                <access type="read">
                  <machine>
                    <group>stanford</group>
                    <world rule="no-download"/>
                  </machine>
                </access>
                <use>
                  <human type="useAndReproduction">Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.</human>
                </use>
              </rightsMetadata>
              <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description rdf:about="info:fedora/druid:bb004bn8654">
                  <fedora:isMemberOf rdf:resource="info:fedora/druid:kz071cg8658"/>
                  <fedora:isMemberOf rdf:resource="info:fedora/druid:nt028fd5773"/>
                  <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:kz071cg8658"/>
                  <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:nt028fd5773"/>
                </rdf:Description>
              </rdf:RDF>
              <oai_dc:dc xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:srw_dc="info:srw/schema/1/dc-schema" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
                <dc:type>StillImage</dc:type>
                <dc:type>digital image</dc:type>
                <dc:subject>Automobile--History</dc:subject>
                <dc:date>1966</dc:date>
                <dc:title>Bryar 250 Trans-American: July 9-10</dc:title>
                <dc:description>Strip Negatives</dc:description>
                <dc:identifier>2012-027NADI-1966-b1_4.3_0015</dc:identifier>
                <dc:relation type="collection">The David Nadig Collection of the Revs Institute</dc:relation>
                <dc:relation type="collection">Revs Institute</dc:relation>
              </oai_dc:dc>
            </publicObject>
        XML
      end

      before do
        stub_request(:get, 'https://purl-test.stanford.edu/bb004bn8654.xml')
          .to_return(status: 200, body: response)
      end

      it 'gets the purl xml for a druid' do
        expect(xml).to be_a(Nokogiri::XML::Document)
        expect(xml.at_xpath('//publicObject').attr('id')).to eq(pid)
      end
    end

    context 'when the response is a 404' do
      before do
        stub_request(:get, 'https://purl-test.stanford.edu/druid:IAmABadDruid.xml')
          .to_return(status: 404, body: '')
        allow(Dor.logger).to receive(:warn)
      end

      let(:pid) { 'druid:IAmABadDruid' }

      it 'does not raise an error' do
        expect(xml).to be_a(Nokogiri::XML::Document)
        expect(Dor.logger).to have_received(:warn)
      end
    end
  end
end
