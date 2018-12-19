# frozen_string_literal: true

require 'spec_helper'

class PublishableItem < ActiveFedora::Base
  include Dor::Identifiable
  include Dor::Contentable
  include Dor::Publishable
  include Dor::Describable
  include Dor::Processable
  include Dor::Releaseable
  include Dor::Rightsable
  include Dor::Governable
  include Dor::Itemizable
end

class DescribableItem < ActiveFedora::Base
  include Dor::Identifiable
  include Dor::Describable
  include Dor::Processable
end

class ItemizableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Describable
end

describe Dor::Publishable do
  before(:each) do
    stub_config
    Dor.configure do
      stacks do
        host 'stacks.stanford.edu'
      end
    end
  end
  after { unstub_config }

  before do
    @item = instantiate_fixture('druid:ab123cd4567', PublishableItem)
    @collection = instantiate_fixture('druid:ab123cd4567', Dor::Collection)
    @apo = instantiate_fixture('druid:fg890hi1234', Dor::AdminPolicyObject)
    allow(@item).to receive(:admin_policy_object).and_return(@apo)
    @mods = <<-EOXML
      <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 version="3.3"
                 xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd">
        <mods:identifier type="local" displayLabel="SUL Resource ID">druid:ab123cd4567</mods:identifier>
      </mods:mods>
    EOXML

    @rights = <<-EOXML
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

    @rels = <<-EOXML
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

    @item.contentMetadata.content = '<contentMetadata/>'
    @item.descMetadata.content    = @mods
    @item.rightsMetadata.content  = @rights
    @item.rels_ext.content        = @rels
    allow(@item).to receive(:generate_public_desc_md).and_return(@mods) # calls Item.find and not needed in general tests
    allow(OpenURI).to receive(:open_uri).with('https://purl-test.stanford.edu/ab123cd4567.xml').and_return('<xml/>')
  end

  it 'has a rightsMetadata datastream' do
    expect(@item.datastreams['rightsMetadata']).to be_a(ActiveFedora::OmDatastream)
  end

  it 'should provide a rightsMetadata datastream builder' do
    rights_md = @apo.defaultObjectRights.content
    expect(@item.datastreams['rightsMetadata'].ng_xml.to_s).not_to be_equivalent_to(rights_md)
    @item.build_datastream('rightsMetadata', true)
    expect(@item.datastreams['rightsMetadata'].ng_xml.to_s).to be_equivalent_to(rights_md)
  end

  describe '#thumb' do
    before do
      expect(Deprecation).to receive(:warn)
    end
    subject { item.thumb }
    let(:item) { @item }
    let(:service) { instance_double(Dor::ThumbnailService, thumb: 'Test Result') }

    it 'calls the thumbnail service' do
      expect(Dor::ThumbnailService).to receive(:new).with(item).and_return(service)
      expect(subject).to eq 'Test Result'
    end
  end

  describe '#thumb_url' do
    before do
      expect(Deprecation).to receive(:warn).at_least(1).times
    end
    it 'should return nil if there is no contentMetadata datastream' do
      expect(@collection.thumb_url).to be_nil
    end

    it 'should return nil if there is no contentMetadata' do
      expect(@item.thumb_url).to be_nil
    end
    it 'should find the first image as the thumb when no specific thumbs are specified' do
      @item.contentMetadata.content = <<-XML
        <?xml version="1.0"?>
        <contentMetadata objectId="druid:ab123cd4567" type="image">
          <resource id="0001" sequence="1" type="image">
            <file id="ab123cd4567_05_0001.jp2" mimetype="image/jp2"/>
          </resource>
        </contentMetadata>
      XML
      expect(@item.thumb_url).to eq('https://stacks.stanford.edu/image/iiif/ab123cd4567%2Fab123cd4567_05_0001/full/!400,400/0/default.jpg')
    end

    it 'should find a page resource marked as thumb with the thumb attribute when there is a resource thumb specified but not the thumb attribute' do
      @item.contentMetadata.content = <<-XML
        <?xml version="1.0"?>
        <contentMetadata objectId="druid:ab123cd4567" type="file">
          <resource id="0001" sequence="1" type="thumb">
            <file id="ab123cd4567_05_0001.jp2" mimetype="image/jp2"/>
            <file id="extra_ignored_image" mimetype="image/jp2"/>
          </resource>
          <resource id="0002" sequence="2" thumb="yes" type="page">
            <file id="ab123cd4567_05_0002.jp2" mimetype="image/jp2"/>
          </resource>
          <resource id="0003" sequence="3" type="page">
            <externalFile fileId="2542A.jp2" mimetype="image/jp2" objectId="druid:cg767mn6478" resourceId="cg767mn6478_1">
          </resource>
        </contentMetadata>
      XML
      expect(@item.encoded_thumb).to eq('ab123cd4567%2Fab123cd4567_05_0002.jp2')
      expect(@item.thumb_url).to eq('https://stacks.stanford.edu/image/iiif/ab123cd4567%2Fab123cd4567_05_0002/full/!400,400/0/default.jpg')
    end
    it 'should find an externalFile image resource when there are no other images' do
      @item.contentMetadata.content = <<-XML
        <?xml version="1.0"?>
        <contentMetadata objectId="druid:ab123cd4567" type="file">
          <resource id="0001" sequence="1" type="file">
            <file id="ab123cd4567_05_0001.pdf" mimetype="file/pdf"/>
          </resource>
          <resource id="0002" sequence="2" type="image">
            <externalFile fileId="2542A.jp2" mimetype="image/jp2" objectId="druid:cg767mn6478" resourceId="cg767mn6478_1">
          </resource>
        </contentMetadata>
      XML
      expect(@item.encoded_thumb).to eq('cg767mn6478%2F2542A.jp2')
      expect(@item.thumb_url).to eq('https://stacks.stanford.edu/image/iiif/cg767mn6478%2F2542A/full/!400,400/0/default.jpg')
    end
    it 'should find an externalFile page resource when there are no other images, even if objectId attribute is missing druid prefix' do
      @item.contentMetadata.content = <<-XML
        <?xml version="1.0"?>
        <contentMetadata objectId="druid:ab123cd4567" type="file">
          <resource id="0001" sequence="1" type="file">
            <file id="ab123cd4567_05_0001.pdf" mimetype="file/pdf"/>
          </resource>
          <resource id="0002" sequence="2" type="page">
            <externalFile fileId="2542A.jp2" mimetype="image/jp2" objectId="cg767mn6478" resourceId="cg767mn6478_1">
          </resource>
        </contentMetadata>
      XML
      expect(@item.encoded_thumb).to eq('cg767mn6478%2F2542A.jp2')
      expect(@item.thumb_url).to eq('https://stacks.stanford.edu/image/iiif/cg767mn6478%2F2542A/full/!400,400/0/default.jpg')
    end
    it 'should find an explicit externalFile thumb resource before another image resource, and encode the space' do
      @item.contentMetadata.content = <<-XML
        <?xml version="1.0"?>
        <contentMetadata objectId="druid:ab123cd4567" type="file">
          <resource id="0001" sequence="1" type="image">
            <file id="ab123cd4567_05_0001.jp2" mimetype="image/jp2"/>
          </resource>
          <resource id="0002" sequence="2" thumb="yes" type="page">
            <externalFile fileId="2542A withspace.jp2" mimetype="image/jp2" objectId="druid:cg767mn6478" resourceId="cg767mn6478_1">
          </resource>
        </contentMetadata>
      XML
      expect(@item.encoded_thumb).to eq('cg767mn6478%2F2542A%20withspace.jp2')
      expect(@item.thumb_url).to eq('https://stacks.stanford.edu/image/iiif/cg767mn6478%2F2542A%20withspace/full/!400,400/0/default.jpg')
    end
    it 'should return nil if no thumb is identified' do
      @item.contentMetadata.content = <<-XML
        <?xml version="1.0"?>
        <contentMetadata objectId="druid:ab123cd4567" type="file">
          <resource id="0001" sequence="1" type="file">
            <file id="some_file.pdf" mimetype="file/pdf"/>
          </resource>
        </contentMetadata>
      XML
      expect(@item.encoded_thumb).to be_nil
      expect(@item.thumb_url).to be_nil
    end
    it 'should return nil if there is no contentMetadata datastream at all' do
      @item.datastreams['contentMetadata'] = nil
      expect(@item.encoded_thumb).to be_nil
      expect(@item.thumb_url).to be_nil
    end
  end

  describe '#public_xml' do
    context 'there are no release tags' do
      before :each do
        expect(@item).to receive(:released_for).and_return({})
        @p_xml = Nokogiri::XML(@item.public_xml)
      end
      it 'does not include a releaseData element and any info in identityMetadata' do
        expect(@p_xml.at_xpath('/publicObject/releaseData')).to be_nil
        expect(@p_xml.at_xpath('/publicObject/identityMetadata/release')).to be_nil
      end
    end

    context 'produces xml with' do
      let(:public_xml) { Nokogiri::XML(@item.public_xml) }
      before(:each) do
        @now = Time.now.utc
        allow(Time).to receive(:now).and_return(@now)
      end

      it 'an encoding of UTF-8' do
        expect(public_xml.encoding).to match(/UTF-8/)
      end
      it 'an id attribute' do
        expect(public_xml.at_xpath('/publicObject/@id').value).to match(/^druid:ab123cd4567/)
      end
      it 'a published attribute' do
        expect(public_xml.at_xpath('/publicObject/@published').value).to eq(@now.xmlschema)
      end
      it 'a published version' do
        expect(public_xml.at_xpath('/publicObject/@publishVersion').value).to eq('dor-services/' + Dor::VERSION)
      end
      it 'identityMetadata' do
        expect(public_xml.at_xpath('/publicObject/identityMetadata')).to be
      end
      it 'no contentMetadata element' do
        expect(public_xml.at_xpath('/publicObject/contentMetadata')).not_to be
      end

      describe 'with contentMetadata present' do
        before do
          @item.contentMetadata.content = <<-XML
            <?xml version="1.0"?>
            <contentMetadata objectId="druid:ab123cd4567" type="file">
              <resource id="0001" sequence="1" type="file">
                <file id="some_file.pdf" mimetype="file/pdf" publish="yes"/>
              </resource>
            </contentMetadata>
          XML
        end
        it 'include contentMetadata' do
          expect(public_xml.at_xpath('/publicObject/contentMetadata')).to be
        end
      end

      it 'rightsMetadata' do
        expect(public_xml.at_xpath('/publicObject/rightsMetadata')).to be
      end
      it 'generated mods' do
        expect(public_xml.at_xpath('/publicObject/mods:mods', 'mods' => 'http://www.loc.gov/mods/v3')).to be
      end

      it 'generated dublin core' do
        expect(public_xml.at_xpath('/publicObject/oai_dc:dc', 'oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/')).to be
      end

      it 'relationships' do
        ns = {
          'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
          'hydra' => 'http://projecthydra.org/ns/relations#',
          'fedora' => 'info:fedora/fedora-system:def/relations-external#',
          'fedora-model' => 'info:fedora/fedora-system:def/model#'
        }
        expect(public_xml.at_xpath('/publicObject/rdf:RDF', ns)).to be
        expect(public_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOf', ns)).to be
        expect(public_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOfCollection', ns)).to be
        expect(public_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isConstituentOf', ns)).to be
        expect(public_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora-model:hasModel', ns)).not_to be
        expect(public_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/hydra:isGovernedBy', ns)).not_to be
      end

      it 'clones of the content of the other datastreams, keeping the originals in tact' do
        expect(@item.datastreams['identityMetadata'].ng_xml.at_xpath('/identityMetadata')).to be
        expect(@item.datastreams['contentMetadata'].ng_xml.at_xpath('/contentMetadata')).to be
        expect(@item.datastreams['rightsMetadata'].ng_xml.at_xpath('/rightsMetadata')).to be
        expect(@item.datastreams['RELS-EXT'].content).to be_equivalent_to @rels
      end

      it 'does not add a thumb node if no thumb is present' do
        expect(public_xml.at_xpath('/publicObject/thumb')).not_to be
      end

      it 'include a thumb node if a thumb is present' do
        @item.contentMetadata.content = <<-XML
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
        p_xml = Nokogiri::XML(@item.public_xml)
        expect(p_xml.at_xpath('/publicObject/thumb').to_xml).to be_equivalent_to('<thumb>ab123cd4567/ab123cd4567_05_0002.jp2</thumb>')
      end

      it 'should expand isMemberOfCollection and isConstituentOf into correct MODS' do
        allow(@item).to receive(:generate_public_desc_md).and_call_original
        # load up collection and constituent parent items from fixture data
        expect(Dor).to receive(:find).with('druid:xh235dd9059').and_return(instantiate_fixture('druid:xh235dd9059', DescribableItem))
        expect(Dor).to receive(:find).with('druid:hj097bm8879').and_return(instantiate_fixture('druid:hj097bm8879', DescribableItem))

        # test that we have 2 expansions
        doc = Nokogiri::XML(@item.generate_public_desc_md)
        expect(doc.xpath('//mods:mods/mods:relatedItem[@type="host"]', 'mods' => 'http://www.loc.gov/mods/v3').size).to eq(2)

        # test the validity of the collection expansion
        xpath_expr = '//mods:mods/mods:relatedItem[@type="host" and not(@displayLabel)]/mods:titleInfo/mods:title'
        expect(doc.xpath(xpath_expr, 'mods' => 'http://www.loc.gov/mods/v3').first.text.strip).to eq('David Rumsey Map Collection at Stanford University Libraries')
        xpath_expr = '//mods:mods/mods:relatedItem[@type="host" and not(@displayLabel)]/mods:location/mods:url'
        expect(doc.xpath(xpath_expr, 'mods' => 'http://www.loc.gov/mods/v3').first.text.strip).to match(/^https?:\/\/purl.*\.stanford\.edu\/xh235dd9059$/)

        # test the validity of the constituent expansion
        xpath_expr = '//mods:mods/mods:relatedItem[@type="host" and @displayLabel="Appears in"]/mods:titleInfo/mods:title'
        expect(doc.xpath(xpath_expr, 'mods' => 'http://www.loc.gov/mods/v3').first.text.strip).to start_with("Carey's American Atlas: Containing Twenty Maps")
        xpath_expr = '//mods:mods/mods:relatedItem[@type="host" and @displayLabel="Appears in"]/mods:location/mods:url'
        expect(doc.xpath(xpath_expr, 'mods' => 'http://www.loc.gov/mods/v3').first.text.strip).to match(/^http:\/\/purl.*\.stanford\.edu\/hj097bm8879$/)
      end

      it 'includes releaseData element from release tags' do
        releases = public_xml.xpath('/publicObject/releaseData/release')
        expect(releases.map(&:inner_text)).to eq %w[true true]
        expect(releases.map{ |r| r['to'] }).to eq %w[Searchworks Some_special_place]
      end

      it 'include a releaseData element when there is content inside it, but does not include this release data in identityMetadata' do
        allow(@item).to receive(:released_for).and_return('' => { 'release' => 'foo' })
        p_xml = Nokogiri::XML(@item.public_xml)
        expect(p_xml.at_xpath('/publicObject/releaseData/release').inner_text).to eq 'foo'
        expect(p_xml.at_xpath('/publicObject/identityMetadata/release')).to be_nil
      end
    end

    context 'with a collection' do
      let(:public_xml) { Nokogiri::XML(@item.public_xml) }
      before(:each) do
        @now = Time.now.utc
        allow(Time).to receive(:now).and_return(@now)
      end

      it 'publishes the expected datastreams' do
        expect(public_xml.at_xpath('/publicObject/identityMetadata')).to be
        expect(public_xml.at_xpath('/publicObject/rightsMetadata')).to be
        expect(public_xml.at_xpath('/publicObject/mods:mods', 'mods' => 'http://www.loc.gov/mods/v3')).to be
        expect(public_xml.at_xpath('/publicObject/rdf:RDF', 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#')).to be
        expect(public_xml.at_xpath('/publicObject/oai_dc:dc', 'oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/')).to be
      end
    end

    describe '#public_xml' do
      it 'handles externalFile references' do
        correctPublicContentMetadata = Nokogiri::XML(read_fixture('hj097bm8879_publicObject.xml')).at_xpath('/publicObject/contentMetadata').to_xml
        @item.contentMetadata.content = read_fixture('hj097bm8879_contentMetadata.xml')

        cover_item = instantiate_fixture('druid:cg767mn6478', Dor::Item)
        allow(Dor).to receive(:find).with(cover_item.pid).and_return(cover_item)
        title_item = instantiate_fixture('druid:jw923xn5254', Dor::Item)
        allow(Dor).to receive(:find).with(title_item.pid).and_return(title_item)

        # generate publicObject XML and verify that the content metadata portion is correct and the correct thumb is present
        public_xml = @item.public_xml
        expect(Nokogiri::XML(public_xml).at_xpath('/publicObject/contentMetadata').to_xml).to be_equivalent_to(correctPublicContentMetadata)
        expect(Nokogiri::XML(public_xml).at_xpath('/publicObject/thumb').to_xml).to be_equivalent_to('<thumb>jw923xn5254/2542B.jp2</thumb>')
      end
    end

    describe '#publish_metadata' do
      it 'calls the service' do
        expect(Deprecation).to receive(:warn)
        expect(Dor::PublishMetadataService).to receive(:publish).with(@item)
        @item.publish_metadata
      end
    end
  end

  describe 'publish remotely' do
    before(:each) do
      Dor::Config.push! { |config| config.dor_services.url 'https://lyberservices-test.stanford.edu/dor' }
      stub_request(:any, 'https://lyberservices-test.stanford.edu/dor/v1/objects/druid:ab123cd4567/publish')
    end
    it 'should hit the correct url' do
      expect(@item.publish_metadata_remotely).to eq('https://lyberservices-test.stanford.edu/dor/v1/objects/druid:ab123cd4567/publish')
    end
  end
end
