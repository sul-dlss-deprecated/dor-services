# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Releaseable do
  before do
    stub_config
  end

  after do
    Dor::Config.pop!
  end

  describe 'handling tags on objects and determining release status' do
    it 'uses only the most recent self tag to determine if an item is released, with no release tags on the collection' do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
         <publicObject id="druid:bb004bn8654" published="2017-04-24T19:05:51Z" publishVersion="dor-services/5.23.0">
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
             <tag>tag : test1</tag>
             <tag>old : tag</tag>
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
             <dc:description>Test</dc:description>
             <dc:description type="contact">test@test.com</dc:description>
             <dc:contributor>test (Author)</dc:contributor>
             <dc:relation type="collection">The David Nadig Collection of the Revs Institute</dc:relation>
             <dc:relation type="collection">Revs Institute</dc:relation>
           </oai_dc:dc>
           <mods xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.loc.gov/mods/v3" version="3.5" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-5.xsd">
             <typeOfResource>still image</typeOfResource>
             <genre authority="att">digital image</genre>
             <subject authority="lcsh">
               <topic>Automobile</topic>
               <topic>History</topic>
             </subject>
             <relatedItem type="original">
               <physicalDescription>
                 <form authority="att">black-and-white negatives</form>
               </physicalDescription>
             </relatedItem>
             <originInfo>
               <dateCreated>1966</dateCreated>
             </originInfo>
             <titleInfo>
               <title>Bryar 250 Trans-American: July 9-10</title>
             </titleInfo>
             <note>Strip Negatives</note>
             <identifier type="local" displayLabel="Revs ID">2012-027NADI-1966-b1_4.3_0015</identifier>
             <abstract>Test</abstract>
             <note type="contact">test@test.com</note>
             <name type="personal">
               <namePart>test</namePart>
               <role>
                 <roleTerm authority="marcrelator" type="text">Author</roleTerm>
               </role>
             </name>
             <relatedItem type="host">
               <titleInfo>
                 <title>The David Nadig Collection of the Revs Institute</title>
               </titleInfo>
               <location>
                 <url>https://sul-purl-test.stanford.edu/kz071cg8658</url>
               </location>
               <typeOfResource collection="yes"/>
             </relatedItem>
             <relatedItem type="host">
               <titleInfo>
                 <title>Revs Institute</title>
               </titleInfo>
               <location>
                 <url>https://sul-purl-test.stanford.edu/nt028fd5773</url>
               </location>
               <typeOfResource collection="yes"/>
             </relatedItem>
             <accessCondition type="useAndReproduction">Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.</accessCondition>
             <accessCondition type="copyright">Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.</accessCondition>
           </mods>
           <releaseData>
             <release to="Revs">false</release>
             <release to="FRDA">true</release>
           </releaseData>
           <thumb>bb004bn8654/2012-027NADI-1966-b1_4.3_0015.jp2</thumb>
         </publicObject>
      XML
      stub_request(:get, 'https://purl-test.stanford.edu/vs298kg2555.xml')
        .and_return(body: xml)
      item = instantiate_fixture('druid:vs298kg2555', Dor::Item)
      expect(item.released_for['Kurita']['release']).to be_truthy
    end

    it 'deals with a bad collection record that references itself and not end up in an infinite loop by skipping the tag check for itself' do
      collection_druid = 'druid:wz243gf4151'
      stub_request(:get, 'https://purl-test.stanford.edu/wz243gf4151.xml')
        .and_return(status: 404)
      collection = instantiate_fixture(collection_druid, Dor::Item)
      allow(collection).to receive(:collections).and_return([collection]) # force it to return itself as a member
      expect(collection.collections.first.id).to eq collection.id # confirm it is a member of itself
      expect(collection.released_for['Kurita']['release']).to be_truthy # we can still get the tags without going into an infinite loop
    end

    it 'merges tags' do
      stub_request(:get, 'https://purl-test.stanford.edu/vs298kg2555.xml')
        .and_return(status: 404)
      item = instantiate_fixture('druid:vs298kg2555', Dor::Item)
      collection = instantiate_fixture('druid:wz243gf4151', Dor::Item)
      allow(item).to receive(:collections).and_return([collection]) # force it to return itself as a member
      expect(item.released_for['Kurita']['release']).to be_truthy # we can still get the tags without going into an infinite loop
    end
  end
end
