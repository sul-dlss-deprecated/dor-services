require 'spec_helper'

class PresentableItem < ActiveFedora::Base
  include Dor::Presentable
end

# Differences between objects will happen betweeen the incoming contentMetadata and DC, that's why they are set as variables in the
# pub_xml template
# Same for the canvas template

describe Dor::Presentable do
  let(:druid) {"druid:bp778zp8790"}

  let(:pub_xml) { <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <publicObject id="druid:bp778zp8790" published="2014-11-11T14:21:01-08:00" publishVersion="dor-services/#{Dor::VERSION}">
      <identityMetadata>
        <sourceId source="sul">M2002_3_06</sourceId>
        <objectId>druid:bp778zp8790</objectId>
        <objectCreator>DOR</objectCreator>
        <objectLabel>Roman Imperial denarius - skipped</objectLabel>
        <objectType>item</objectType>
        <adminPolicy>druid:cx452zj4329</adminPolicy>
        <otherId name="label"/>
        <otherId name="uuid">6b9ddfb2-1e56-11e4-8810-0050569b3c3c</otherId>
        <tag>Process : Content Type : Image</tag>
        <tag>Project : R. M. Row collection of Roman Imperial coins</tag>
        <tag>JIRA : PROJQUEUE-108</tag>
        <tag>DPG : Curator Request : Jordan</tag>
        <tag>Registered By : astrids</tag>
        <tag>Remediated By : 4.14.3</tag>
      </identityMetadata>
      #{content_md}
      <rightsMetadata>
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
          <human type="useAndReproduction">You do not need to obtain permission to use materials in the public domain.</human>
          <human type="creativeCommons"/>
          <machine type="creativeCommons"/>
        </use>
        <copyright>
         <human type="copyright">(c) 2009 by Jasper Wilcox. All rights reserved.</human>
        </copyright>
      </rightsMetadata>
      <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about="info:fedora/druid:bp778zp8790">
          <fedora:isMemberOf rdf:resource="info:fedora/druid:dq017bh9237"/>
          <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:dq017bh9237"/>
        </rdf:Description>
      </rdf:RDF>
      #{dc}
    </publicObject>
  XML
  }

  let(:manifest) {<<-JSON
    {
      "@context": "http://iiif.io/api/presentation/2/context.json",
      "@id": "https://purl-dev.stanford.edu/bp778zp8790/iiif/manifest.json",
      "@type": "sc:Manifest",
      "label": "Roman Imperial denarius",
      "attribution": "(c) 2009 by Jasper Wilcox. All rights reserved.",
      "logo": { 
        "@id": "https://stacks.stanford.edu/image/iiif/wy534zh7137%2FSULAIR_rosette/full/400,/0/default.jpg", 
        "service": { 
          "@context": "http://iiif.io/api/image/2/context.json", 
          "@id": "https://stacks.stanford.edu/image/iiif/wy534zh7137%2FSULAIR_rosette", 
          "profile": "http://iiif.io/api/image/2/level1.json" 
        } 
      },
      "seeAlso": {
        "@id": "https://purl-dev.stanford.edu/bp778zp8790.mods",
        "format": "application/mods+xml"
      },
      #{description_and_md}
      #{thumbnail}
      "sequences": [
        {
          "@id": "https://purl-dev.stanford.edu/bp778zp8790/sequence-1",
          "@type": "sc:Sequence",
          "label": "Current order",
          #{canvases}
        }
      ]
    }

    JSON
  }

  before(:each) do
    Dor::Config.push! do
      stacks do
        document_cache_host 'purl-dev.stanford.edu'
        local_stacks_root '/stacks'
        local_document_cache_root '/purl/document_cache'
        local_workspace_root '/dor/workspace'
        url 'http://stacks-dev.stanford.edu'
        iiif_profile 'http://iiif.io/api/image/2/level1.json'
      end
    end
  end

  context 'basic images' do

    let(:content_md) {<<-XML
      <contentMetadata objectId="bp778zp8790" type="image">
        <resource id="bp778zp8790_1" sequence="1" type="image">
          <label>Image 1</label>
          <file id="bp778zp8790_00_0001.jp2" mimetype="image/jp2" size="132906">
            <imageData width="790" height="790"/>
          </file>
        </resource>
        <resource id="bp778zp8790_2" sequence="2" type="image">
          <label>Image 2</label>
          <file id="bp778zp8790_00_0002.jp2" mimetype="image/jp2" size="132828">
            <imageData width="790" height="790"/>
          </file>
        </resource>
      </contentMetadata>
      XML
    }

    let(:dc) {<<-XML
      <oai_dc:dc xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:srw_dc="info:srw/schema/1/dc-schema" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
        <dc:title>Roman Imperial denarius</dc:title>
        <dc:contributor>, Tiberius, 42 B.C.-37 A.D. (authority)</dc:contributor>
        <dc:contributor>Second Contributor</dc:contributor>
        <dc:type>Coins (money)</dc:type>
        <dc:date>21-23</dc:date>
        <dc:language>lat</dc:language>
        <dc:format>1 coin (3.655 grams)</dc:format>
        <dc:format>Silver</dc:format>
        <dc:format>image/jpeg</dc:format>
        <dc:description displayLabel="Mint/Source">Lugdunum</dc:description>
        <dc:description displayLabel="Obverse type">portrait of Tiberius, laureate, facing right, laurel ribbons divergent</dc:description>
        <dc:description displayLabel="Obverse inscription">TI CAESAR DIVI AUG F AUGUSTUS</dc:description>
        <dc:description displayLabel="Reverse type">female seated on chair, facing right, laurel branch in left hand, spear in right hand, 2 lines below chair with decorated legs</dc:description>
        <dc:description displayLabel="Reverse inscription">PONTIF MAXIM</dc:description>
        <dc:description>No dl description</dc:description>
        <dc:description displayLabel="Coin number">3.06</dc:description>
        <dc:description type="citation/reference" displayLabel="Bibliography">Row, R. M. The Tribute Penny: A Guide to the Pontif Maxim Aureus-Denarius Issue of Tiberius, AD 14-37. Austin, 2013. Type 3.</dc:description>
        <dc:identifier>sul:M2002_3_06</dc:identifier>
        <dc:identifier>: bp778zp8790</dc:identifier>
        <dc:publisher>Publisher's Clearinghouse</dc:publisher>
        <dc:relation type="collection">R. M. Row collection of Roman Imperial coins</dc:relation>
      </oai_dc:dc>
      XML
    }

    let(:description_and_md) {<<-JSON
      "description": "No dl description",
      "metadata": [
          {
            "label": "Contributor",
            "value": ", Tiberius, 42 B.C.-37 A.D. (authority)"
          },
          {
            "label": "Contributor",
            "value": "Second Contributor"
          },
          {
            "label": "Publisher",
            "value": "Publisher's Clearinghouse"
          },
          {
            "label": "Date",
            "value": "21-23"
          },
          {
            "label": "PublishVersion",
            "value": "dor-services/#{Dor::VERSION}"
          }
      ],
      JSON
    }

    let(:thumbnail) {<<-JSON
      "thumbnail": {
          "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2Fbp778zp8790_00_0001/full/400,/0/default.jpg",
          "service": {
            "@context": "http://iiif.io/api/image/2/context.json",
            "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2Fbp778zp8790_00_0001",
            "profile": "http://iiif.io/api/image/2/level1.json"
          }
      },
      JSON
    }

    let(:canvases) {<<-JSON
      "canvases": [
        {
          "@id": "https://purl-dev.stanford.edu/bp778zp8790/canvas/canvas-1",
          "@type": "sc:Canvas",
          "label": "Image 1",
          "height": 790,
          "width": 790,
          "images": [
            {
              "@id": "https://purl-dev.stanford.edu/bp778zp8790/imageanno/anno-1",
              "@type": "oa:Annotation",
              "motivation": "sc:painting",
              "on": "https://purl-dev.stanford.edu/bp778zp8790/canvas/canvas-1",
              "resource": {
                "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2Fbp778zp8790_00_0001/full/full/0/default.jpg",
                "@type": "dcterms:Image",
                "format": "image/jpeg",
                "height": 790,
                "width": 790,
                "service": {
                  "@context": "http://iiif.io/api/image/2/context.json",
                  "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2Fbp778zp8790_00_0001",
                  "profile": "http://iiif.io/api/image/2/level1.json"
                }
              }
            }
          ]
        },
        {
          "@id": "https://purl-dev.stanford.edu/bp778zp8790/canvas/canvas-2",
          "@type": "sc:Canvas",
          "label": "Image 2",
          "height": 790,
          "width": 790,
          "images": [
            {
              "@id": "https://purl-dev.stanford.edu/bp778zp8790/imageanno/anno-2",
              "@type": "oa:Annotation",
              "motivation": "sc:painting",
              "on": "https://purl-dev.stanford.edu/bp778zp8790/canvas/canvas-2",
              "resource": {
                "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2Fbp778zp8790_00_0002/full/full/0/default.jpg",
                "@type": "dcterms:Image",
                "format": "image/jpeg",
                "height": 790,
                "width": 790,
                "service": {
                  "@context": "http://iiif.io/api/image/2/context.json",
                  "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2Fbp778zp8790_00_0002",
                  "profile": "http://iiif.io/api/image/2/level1.json"
                }
              }
            }
          ]
        }
      ]
      JSON
    }

    describe '#build_iiif_manifest for images' do
      it 'transforms publicObject xml to a IIIF 2.0 Presentation manifest' do
        item = PresentableItem.new(:pid => druid)
        pub_doc = Nokogiri::XML pub_xml
        built_json = JSON.parse(item.build_iiif_manifest(pub_doc))
        expected_json = JSON.parse manifest
        expect(built_json).to eq(expected_json)
      end

      describe 'error handling' do

        let(:content_md) {<<-XML
          <contentMetadata objectId="bp778zp8790" type="map">
            <resource id="bp778zp8790_1" sequence="1" type="image">
              <file id="bp778zp8790_00_0001.jp2" mimetype="image/jp2" size="132906">
                <imageData width="790" height="790"/>
              </file>
            </resource>
          </contentMetadata>
          XML
        }

        it 'deals with contentMetadata/resource nodes without failing' do
          item = PresentableItem.new(:pid => druid)
          pub_doc = Nokogiri::XML pub_xml
          built_json = JSON.parse(item.build_iiif_manifest(pub_doc))
          expect(built_json['sequences'].first['canvases'].first['label']).to eq('image')
        end
      end
    end

    describe '#iiif_presentation_manifest_needed?' do

      it 'returns true when the public_xml contentMetadata has an image resource' do
        item = PresentableItem.new(:pid => druid)
        pub_doc = Nokogiri::XML pub_xml
        expect(item.iiif_presentation_manifest_needed? pub_doc).to be true
      end

      describe 'for a map' do

        let(:content_md) {<<-XML
          <contentMetadata objectId="bp778zp8790" type="map">
            <resource id="bp778zp8790_1" sequence="1" type="image">
              <label>Image 1</label>
              <file id="bp778zp8790_00_0001.jp2" mimetype="image/jp2" size="132906">
                <imageData width="790" height="790"/>
              </file>
            </resource>
          </contentMetadata>
          XML
        }

        it 'returns true when the public_xml contentMetadata has a map resource' do
          item = PresentableItem.new(:pid => druid)

          pub_doc = Nokogiri::XML pub_xml
          expect(item.iiif_presentation_manifest_needed? pub_doc).to be true
        end

      end

    end

  end

  context 'book pages' do
    let(:content_md) {<<-XML
      <contentMetadata objectId="druid:bp778zp8790" type="book">
          <resource id="image_1" sequence="1" type="page">
            <label>1</label>
            <file id="1.jp2" mimetype="image/jp2" format="JPEG2000" size="522205">
              <imageData height="1740" width="1771"/>
            </file>
          </resource>
          <resource id="image_2" sequence="2" type="page">
            <label>2</label>
            <file id="2.jp2" mimetype="image/jp2" format="JPEG2000" size="521630">
              <imageData height="1740" width="1771"/>
            </file>
          </resource>
          <resource id="image_3" sequence="3" type="page">
            <label>3</label>
            <file id="3.jp2" mimetype="image/jp2" format="JPEG2000" size="44542">
              <imageData height="1740" width="1771"/>
            </file>
          </resource>
      </contentMetadata>
      XML
    }

    let(:dc) {<<-XML
      <oai_dc:dc xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:srw_dc="info:srw/schema/1/dc-schema" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
        <dc:title>Roman Imperial denarius</dc:title>
        <dc:contributor>, Tiberius, 42 B.C.-37 A.D. (authority)</dc:contributor>
        <dc:type>Coins (money)</dc:type>
        <dc:date>21-23</dc:date>
        <dc:language>lat</dc:language>
        <dc:format>1 coin (3.655 grams)</dc:format>
        <dc:format>Silver</dc:format>
        <dc:format>image/jpeg</dc:format>
        <dc:description displayLabel="Mint/Source">Lugdunum</dc:description>
        <dc:description displayLabel="Obverse type">portrait of Tiberius, laureate, facing right, laurel ribbons divergent</dc:description>
        <dc:description displayLabel="Obverse inscription">TI CAESAR DIVI AUG F AUGUSTUS</dc:description>
        <dc:description displayLabel="Reverse type">female seated on chair, facing right, laurel branch in left hand, spear in right hand, 2 lines below chair with decorated legs</dc:description>
        <dc:description displayLabel="Reverse inscription">PONTIF MAXIM</dc:description>
        <dc:description displayLabel="Coin number">3.06</dc:description>
        <dc:description type="citation/reference" displayLabel="Bibliography">Row, R. M. The Tribute Penny: A Guide to the Pontif Maxim Aureus-Denarius Issue of Tiberius, AD 14-37. Austin, 2013. Type 3.</dc:description>
        <dc:identifier>sul:M2002_3_06</dc:identifier>
        <dc:identifier>: bp778zp8790</dc:identifier>
        <dc:relation type="collection">R. M. Row collection of Roman Imperial coins</dc:relation>
      </oai_dc:dc>
      XML
    }

    let(:description_and_md) {<<-JSON
      "metadata": [
          {
            "label": "Contributor",
            "value": ", Tiberius, 42 B.C.-37 A.D. (authority)"
          },
          {
            "label": "Date",
            "value": "21-23"
          },
          {
            "label": "PublishVersion",
            "value": "dor-services/#{Dor::VERSION}"
          }
      ],
      JSON
    }

    let(:thumbnail) {<<-JSON
      "thumbnail": {
          "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2F1/full/400,/0/default.jpg",
          "service": {
            "@context": "http://iiif.io/api/image/2/context.json",
            "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2F1",
            "profile": "http://iiif.io/api/image/2/level1.json"
          }
      },
      JSON
    }

    let(:canvases) {<<-JSON
      "canvases": [
        {
          "@id": "https://purl-dev.stanford.edu/bp778zp8790/canvas/canvas-1",
          "@type": "sc:Canvas",
          "label": "1",
          "height": 1740,
          "width": 1771,
          "images": [
            {
              "@id": "https://purl-dev.stanford.edu/bp778zp8790/imageanno/anno-1",
              "@type": "oa:Annotation",
              "motivation": "sc:painting",
              "on": "https://purl-dev.stanford.edu/bp778zp8790/canvas/canvas-1",
              "resource": {
                "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2F1/full/full/0/default.jpg",
                "@type": "dcterms:Image",
                "format": "image/jpeg",
                "height": 1740,
                "width": 1771,
                "service": {
                  "@context": "http://iiif.io/api/image/2/context.json",
                  "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2F1",
                  "profile": "http://iiif.io/api/image/2/level1.json"
                }
              }
            }
          ]
        },
        {
          "@id": "https://purl-dev.stanford.edu/bp778zp8790/canvas/canvas-2",
          "@type": "sc:Canvas",
          "label": "2",
          "height": 1740,
          "width": 1771,
          "images": [
            {
              "@id": "https://purl-dev.stanford.edu/bp778zp8790/imageanno/anno-2",
              "@type": "oa:Annotation",
              "motivation": "sc:painting",
              "on": "https://purl-dev.stanford.edu/bp778zp8790/canvas/canvas-2",
              "resource": {
                "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2F2/full/full/0/default.jpg",
                "@type": "dcterms:Image",
                "format": "image/jpeg",
                "height": 1740,
                "width": 1771,
                "service": {
                  "@context": "http://iiif.io/api/image/2/context.json",
                  "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2F2",
                  "profile": "http://iiif.io/api/image/2/level1.json"
                }
              }
            }
          ]
        },
        {
          "@id": "https://purl-dev.stanford.edu/bp778zp8790/canvas/canvas-3",
          "@type": "sc:Canvas",
          "label": "3",
          "height": 1740,
          "width": 1771,
          "images": [
            {
              "@id": "https://purl-dev.stanford.edu/bp778zp8790/imageanno/anno-3",
              "@type": "oa:Annotation",
              "motivation": "sc:painting",
              "on": "https://purl-dev.stanford.edu/bp778zp8790/canvas/canvas-3",
              "resource": {
                "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2F3/full/full/0/default.jpg",
                "@type": "dcterms:Image",
                "format": "image/jpeg",
                "height": 1740,
                "width": 1771,
                "service": {
                  "@context": "http://iiif.io/api/image/2/context.json",
                  "@id": "http://stacks-dev.stanford.edu/image/iiif/bp778zp8790%2F3",
                  "profile": "http://iiif.io/api/image/2/level1.json"
                }
              }
            }
          ]
        }
      ]
      JSON
    }

    describe '#build_iiif_manifest' do
      it 'transforms publicObject xml to a IIIF 2.0 Presentation manifest' do
        item = PresentableItem.new(:pid => druid)
        pub_doc = Nokogiri::XML pub_xml
        built_json = JSON.parse(item.build_iiif_manifest(pub_doc))

        expected_json = JSON.parse manifest
        expected_json['viewingHint'] = 'paged'
        expect(built_json).to eq(expected_json)
      end
    end

    describe '#iiif_presentation_manifest_needed?' do
      it 'returns true when the public_xml contentMetadata has an image resource' do
        item = PresentableItem.new(:pid => druid)
        pub_doc = Nokogiri::XML pub_xml
        expect(item.iiif_presentation_manifest_needed? pub_doc).to be true
      end
    end
  end
end
