# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::PublicXmlService do
  let(:item) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }

  subject(:service) { described_class.new(item) }

  describe '#to_xml' do
    subject(:xml) { service.to_xml }

    after { unstub_config }

    let(:rels) do
      <<-EOXML
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
      stub_config
      Dor.configure do
        stacks do
          host 'stacks.stanford.edu'
        end
      end
      mods = <<-EOXML
        <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   version="3.3"
                   xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd">
          <mods:identifier type="local" displayLabel="SUL Resource ID">druid:ab123cd4567</mods:identifier>
        </mods:mods>
      EOXML

      rights = <<-EOXML
        <rightsMetadata objectId="druid:ab123cd4567">
          <copyright>
            <human>(c) Copyright 2010 by Sebastian Jeremias Osterfeld</human>
          </copyright>
          </access>
          <access type="read">
            <machine>
              <group>stanford:stanford</group>
            </machine>
          </access>
          <use>
            <machine type="creativeCommons">by-sa</machine>
            <human type="creativeCommons">CC Attribution Share Alike license</human>
          </use>
        </rightsMetadata>
      EOXML

      item.contentMetadata.content = '<contentMetadata/>'
      item.descMetadata.content    = mods
      item.rightsMetadata.content  = rights
      item.rels_ext.content        = rels
      allow_any_instance_of(Dor::PublicDescMetadataService).to receive(:ng_xml).and_return(Nokogiri::XML(mods)) # calls Item.find and not needed in general tests
      allow(OpenURI).to receive(:open_uri).with('https://purl-test.stanford.edu/ab123cd4567.xml').and_return('<xml/>')
      WebMock.disable_net_connect!
    end
    let(:ng_xml) { Nokogiri::XML(xml) }

    context 'when there are no release tags' do
      before do
        expect(item).to receive(:released_for).and_return({})
      end

      it 'does not include a releaseData element and any info in identityMetadata' do
        expect(ng_xml.at_xpath('/publicObject/releaseData')).to be_nil
        expect(ng_xml.at_xpath('/publicObject/identityMetadata/release')).to be_nil
      end
    end

    context 'produces xml with' do
      let(:now) { Time.now.utc }
      before do
        allow(Time).to receive(:now).and_return(now)
      end

      it 'an encoding of UTF-8' do
        expect(ng_xml.encoding).to match(/UTF-8/)
      end
      it 'an id attribute' do
        expect(ng_xml.at_xpath('/publicObject/@id').value).to match(/^druid:ab123cd4567/)
      end
      it 'a published attribute' do
        expect(ng_xml.at_xpath('/publicObject/@published').value).to eq(now.xmlschema)
      end
      it 'a published version' do
        expect(ng_xml.at_xpath('/publicObject/@publishVersion').value).to eq('dor-services/' + Dor::VERSION)
      end
      it 'identityMetadata' do
        expect(ng_xml.at_xpath('/publicObject/identityMetadata')).to be
      end
      it 'no contentMetadata element' do
        expect(ng_xml.at_xpath('/publicObject/contentMetadata')).not_to be
      end

      describe 'with contentMetadata present' do
        before do
          item.contentMetadata.content = <<-XML
            <?xml version="1.0"?>
            <contentMetadata objectId="druid:ab123cd4567" type="file">
              <resource id="0001" sequence="1" type="file">
                <file id="some_file.pdf" mimetype="file/pdf" publish="yes"/>
              </resource>
            </contentMetadata>
          XML
        end
        it 'include contentMetadata' do
          expect(ng_xml.at_xpath('/publicObject/contentMetadata')).to be
        end
      end

      it 'rightsMetadata' do
        expect(ng_xml.at_xpath('/publicObject/rightsMetadata')).to be
      end
      it 'generated mods' do
        expect(ng_xml.at_xpath('/publicObject/mods:mods', 'mods' => 'http://www.loc.gov/mods/v3')).to be
      end

      it 'generated dublin core' do
        expect(ng_xml.at_xpath('/publicObject/oai_dc:dc', 'oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/')).to be
      end

      it 'relationships' do
        ns = {
          'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
          'hydra' => 'http://projecthydra.org/ns/relations#',
          'fedora' => 'info:fedora/fedora-system:def/relations-external#',
          'fedora-model' => 'info:fedora/fedora-system:def/model#'
        }
        expect(ng_xml.at_xpath('/publicObject/rdf:RDF', ns)).to be
        expect(ng_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOf', ns)).to be
        expect(ng_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOfCollection', ns)).to be
        expect(ng_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isConstituentOf', ns)).to be
        expect(ng_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora-model:hasModel', ns)).not_to be
        expect(ng_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/hydra:isGovernedBy', ns)).not_to be
      end

      it 'clones of the content of the other datastreams, keeping the originals in tact' do
        expect(item.datastreams['identityMetadata'].ng_xml.at_xpath('/identityMetadata')).to be
        expect(item.datastreams['contentMetadata'].ng_xml.at_xpath('/contentMetadata')).to be
        expect(item.datastreams['rightsMetadata'].ng_xml.at_xpath('/rightsMetadata')).to be
        expect(item.datastreams['RELS-EXT'].content).to be_equivalent_to rels
      end

      it 'does not add a thumb node if no thumb is present' do
        expect(ng_xml.at_xpath('/publicObject/thumb')).not_to be
      end

      it 'include a thumb node if a thumb is present' do
        item.contentMetadata.content = <<-XML
          <?xml version="1.0"?>
          <contentMetadata objectId="druid:ab123cd4567" type="map">
            <resource id="0001" sequence="1" type="image">
              <file id="ab123cd4567_05_0001.jp2" mimetype="image/jp2"/>
            </resource>
            <resource id="0002" sequence="2" thumb="yes" type="image">
              <file id="ab123cd4567_05_0002.jp2" mimetype="image/jp2"/>
            </resource>
          </contentMetadata>
        XML
        expect(ng_xml.at_xpath('/publicObject/thumb').to_xml).to be_equivalent_to('<thumb>ab123cd4567/ab123cd4567_05_0002.jp2</thumb>')
      end

      it 'includes releaseData element from release tags' do
        releases = ng_xml.xpath('/publicObject/releaseData/release')
        expect(releases.map(&:inner_text)).to eq %w[true true]
        expect(releases.map{ |r| r['to'] }).to eq %w[Searchworks Some_special_place]
      end

      it 'include a releaseData element when there is content inside it, but does not include this release data in identityMetadata' do
        allow(item).to receive(:released_for).and_return('' => { 'release' => 'foo' })
        expect(ng_xml.at_xpath('/publicObject/releaseData/release').inner_text).to eq 'foo'
        expect(ng_xml.at_xpath('/publicObject/identityMetadata/release')).to be_nil
      end
    end

    context 'with a collection' do
      it 'publishes the expected datastreams' do
        expect(ng_xml.at_xpath('/publicObject/identityMetadata')).to be
        expect(ng_xml.at_xpath('/publicObject/rightsMetadata')).to be
        expect(ng_xml.at_xpath('/publicObject/mods:mods', 'mods' => 'http://www.loc.gov/mods/v3')).to be
        expect(ng_xml.at_xpath('/publicObject/rdf:RDF', 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#')).to be
        expect(ng_xml.at_xpath('/publicObject/oai_dc:dc', 'oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/')).to be
      end
    end

    describe '#public_xml' do
      it 'handles externalFile references' do
        correct_content_md = Nokogiri::XML(read_fixture('hj097bm8879_publicObject.xml')).at_xpath('/publicObject/contentMetadata').to_xml
        item.contentMetadata.content = read_fixture('hj097bm8879_contentMetadata.xml')

        cover_item = instantiate_fixture('druid:cg767mn6478', Dor::Item)
        allow(Dor).to receive(:find).with(cover_item.pid).and_return(cover_item)
        title_item = instantiate_fixture('druid:jw923xn5254', Dor::Item)
        allow(Dor).to receive(:find).with(title_item.pid).and_return(title_item)

        # generate publicObject XML and verify that the content metadata portion is correct and the correct thumb is present
        expect(ng_xml.at_xpath('/publicObject/contentMetadata').to_xml).to be_equivalent_to(correct_content_md)
        expect(ng_xml.at_xpath('/publicObject/thumb').to_xml).to be_equivalent_to('<thumb>jw923xn5254/2542B.jp2</thumb>')
      end
    end

    context 'when there are errors for externalFile references' do
      it 'is missing resourceId and mimetype attributes' do
        item.contentMetadata.content = <<-EOXML
        <contentMetadata objectId="hj097bm8879" type="map">
          <resource id="hj097bm8879_1" sequence="1" type="image">
            <externalFile fileId="2542A.jp2" objectId="druid:cg767mn6478"/>
            <relationship objectId="druid:cg767mn6478" type="alsoAvailableAs"/>
          </resource>
        </contentMetadata>
        EOXML

        # generate publicObject XML and verify that the content metadata portion is invalid
        expect { xml }.to raise_error(ArgumentError)
      end

      it 'has blank resourceId attribute' do
        item.contentMetadata.content = <<-EOXML
        <contentMetadata objectId="hj097bm8879" type="map">
          <resource id="hj097bm8879_1" sequence="1" type="image">
            <externalFile fileId="2542A.jp2" objectId="druid:cg767mn6478" resourceId=" " mimetype="image/jp2"/>
            <relationship objectId="druid:cg767mn6478" type="alsoAvailableAs"/>
          </resource>
        </contentMetadata>
        EOXML

        # generate publicObject XML and verify that the content metadata portion is invalid
        expect { xml }.to raise_error(ArgumentError)
      end

      it 'has blank fileId attribute' do
        item.contentMetadata.content = <<-EOXML
        <contentMetadata objectId="hj097bm8879" type="map">
          <resource id="hj097bm8879_1" sequence="1" type="image">
            <externalFile fileId=" " objectId="druid:cg767mn6478" resourceId="cg767mn6478_1" mimetype="image/jp2"/>
            <relationship objectId="druid:cg767mn6478" type="alsoAvailableAs"/>
          </resource>
        </contentMetadata>
        EOXML

        # generate publicObject XML and verify that the content metadata portion is invalid
        expect { xml }.to raise_error(ArgumentError)
      end

      it 'has blank objectId attribute' do
        item.contentMetadata.content = <<-EOXML
        <contentMetadata objectId="hj097bm8879" type="map">
          <resource id="hj097bm8879_1" sequence="1" type="image">
            <externalFile fileId="2542A.jp2" objectId=" " resourceId="cg767mn6478_1" mimetype="image/jp2"/>
            <relationship objectId="druid:cg767mn6478" type="alsoAvailableAs"/>
          </resource>
        </contentMetadata>
        EOXML

        # generate publicObject XML and verify that the content metadata portion is invalid
        expect { xml }.to raise_error(ArgumentError)
      end
    end
  end
end
