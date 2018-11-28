# encoding: utf-8
# frozen_string_literal: true

# Japanese script requires UTF-8

require 'spec_helper'

describe 'Dor::Releaseable' do
  before :each do
    stub_config
    @item = instantiate_fixture('druid:ab123cd4567', Dor::Item)
    # TODO: move xml to fixture file, obviously
    allow(@item).to receive(:get_xml_from_purl).and_return(Nokogiri::HTML <<~END_OF_HTML
      <?xml version="1.0" encoding="UTF-8"?>
      <publicObject id="druid:vs298kg2555" published="2015-01-06T11:54:57-08:00">
        <identityMetadata>
          <sourceId source="sul">36105131187747</sourceId>
          <objectId>druid:vs298kg2555</objectId>
          <objectCreator>DOR</objectCreator>
          <objectLabel>Kūchū shashin sokuzu yōzu Seibu Papua jūmanbun no ichi</objectLabel>
          <objectType>item</objectType>
          <adminPolicy>druid:xs835jp8197</adminPolicy>
          <otherId name="barcode">36105131187747</otherId>
          <otherId name="uuid">28e9b126-272c-11e4-8557-0050569b3c3c</otherId>
          <tag>Process : Content Type : Map</tag>
          <tag>Project : Japanese Military Maps : Batch 24</tag>
          <tag>LAB : MAPS</tag>
          <tag>Registered By : shizuka4</tag>
          <tag>Remediated By : 4.15.4</tag>
        </identityMetadata>
        <contentMetadata objectId="vs298kg2555" type="map">
          <resource id="vs298kg2555_1" sequence="1" type="image">
            <label>Image 1</label>
            <file id="vs298kg2555_00_0001.jp2" mimetype="image/jp2" size="31184994">
              <imageData width="14478" height="11432"/>
            </file>
          </resource>
        </contentMetadata>
        <rightsMetadata>
          <copyright>
            <human type="copyright">Property rights reside with the repository. Copyright © Stanford University. All Rights Reserved.</human>
          </copyright>
          <access type="discover">
            <machine>
              <world/>
            </machine>
          </access>
          <access type="read">
            <machine>
              <world/>
            </machine>
          </access>
          <use>
            <human type="useAndReproduction">Image from the Map Collections courtesy Stanford University Libraries.  If you have questions, please contact the Branner Earth Science Library &amp; Map Collections at brannerlibrary@stanford.edu.</human>
            <machine type="creativeCommons">by-nc</machine>
            <human type="creativeCommons">Attribution Non-Commercial 3.0 Unported</human>
          </use>
        </rightsMetadata>
        <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about="info:fedora/druid:vs298kg2555">
            <fedora:isMemberOf rdf:resource="info:fedora/druid:fs078sw0006"/>
            <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:fs078sw0006"/>
          </rdf:Description>
        </rdf:RDF>
        <oai_dc:dc xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:srw_dc="info:srw/schema/1/dc-schema" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
          <dc:title>Kūchū shashin sokuzu yōzu Seibu Papua jūmanbun no ichi</dc:title>
          <dc:title>Seibu Papua jūmanbun no ichi</dc:title>
          <dc:contributor>Japan Rikugun. Sanbō Honbu.</dc:contributor>
          <dc:contributor>Japan Rikugun. Chi Butai, Dai 1602.</dc:contributor>
          <dc:contributor>Japan Rikugun. Oka Butai, Dai 10414.</dc:contributor>
          <dc:contributor>Japan Rikugun. Oka Butai, Dai 1601.</dc:contributor>
          <dc:type>map</dc:type>
          <dc:date>1943-1944</dc:date>
          <dc:date>Shōwa 18-19 [1943-1944]</dc:date>
          <dc:publisher>Sanbō Honbu</dc:publisher>
          <dc:date>昭和18-19 [1943-1944]</dc:date>
          <dc:publisher>参謀本部,</dc:publisher>
          <dc:language>jpn</dc:language>
          <dc:format>maps : some col. ; 46 x 56 cm.or smaller.</dc:format>
          <dc:description type="statement of responsibility">Sanbō Honbu seihan.</dc:description>
          <dc:description>Relief shown by form lines and spot heights.</dc:description>
          <dc:description>Most maps based on aerial photo maps made by Chi Dai 1602 Butai, Oka Dai 10414 Butai, and Oka Dai 1601 Butai.</dc:description>
          <dc:description>In Japanese.</dc:description>
          <dc:coverage>Scale 1:100,000.</dc:coverage>
          <dc:coverage>Papua (Indonesia)</dc:coverage>
          <dc:subject>G8073.I7 S100 .J3</dc:subject>
          <dc:contributor>Japan 陸軍. 参謀本部</dc:contributor>
          <dc:title>空中寫真測圖要圖西部パプア十万分一</dc:title>
          <dc:description type="statement of responsibility">参謀本部製版.</dc:description>
          <dc:title>西部パプア十万分一</dc:title>
          <dc:relation type="collection">Japanese Military Maps</dc:relation>
        </oai_dc:dc>
        <releaseData>
          <release to="some_special_place">true</release>
          <release to="Searchworks">false</release>
          <release to="Former_place">true</release>
        </releaseData>
      </publicObject>
    END_OF_HTML
                                                          )
  end
  after :each do
    unstub_config
  end
  it 'released_for pulls from identityMetadata for authoritative values (not PURL)' do
    expect(@item.released_for).to match a_hash_including(
      'Searchworks'        => { 'release' => true },
      'Some_special_place' => { 'release' => true }, # hey, free annoying capitalization!
      'Former_place'       => { 'release' => false } # because it isn't in identityMetadata!
    )
    expect(@item.released_for).not_to match a_hash_including('other_place')
  end
  it 'should return nil if no tags exist on an item with regard to that target' do
    expect(@item.released_for['Runner II']).to be_nil
  end
end
