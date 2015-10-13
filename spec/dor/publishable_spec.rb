require 'spec_helper'

class PublishableItem < ActiveFedora::Base
  include Dor::Publishable
  include Dor::Processable
  include Dor::Releaseable
end

describe Dor::Publishable do
  before(:each) { stub_config   }
  after(:each)  { unstub_config }

  before :each do
    @item = instantiate_fixture('druid:ab123cd4567', PublishableItem)
    @apo  = instantiate_fixture('druid:fg890hi1234', Dor::AdminPolicyObject)
    @item.stub(:admin_policy_object).and_return(@apo)
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
          <fedora:isMemberOf rdf:resource="info:fedora/druid:987654"></fedora:isMemberOf>
          <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:987654"></fedora:isMemberOfCollection>
        </rdf:Description>
      </rdf:RDF>
    EOXML

    @item.contentMetadata.content = '<contentMetadata/>'
    @item.descMetadata.content = @mods
    @item.rightsMetadata.content = @rights
    @item.rels_ext.content = @rels
    allow(@item).to receive(:add_collection_reference).and_return(@mods)
    allow(OpenURI).to receive(:open_uri).with('https://purl-test.stanford.edu/ab123cd4567.xml').and_return('<xml/>')
  end

  it 'has a rightsMetadata datastream' do
    @item.datastreams['rightsMetadata'].should be_a(ActiveFedora::OmDatastream)
  end

  it 'should provide a rightsMetadata datastream builder' do
    rights_md = @apo.defaultObjectRights.content
    @item.datastreams['rightsMetadata'].ng_xml.to_s.should_not be_equivalent_to(rights_md)
    @item.build_datastream('rightsMetadata', true)
    @item.datastreams['rightsMetadata'].ng_xml.to_s.should be_equivalent_to(rights_md)
  end

  describe '#public_xml' do
    context 'produces xml with' do
      before(:each) do
        @now = Time.now
        expect(Time).to receive(:now).and_return(@now).at_least(:once)
        @p_xml = Nokogiri::XML(@item.public_xml)
      end

      it 'an encoding of UTF-8' do
        expect(@p_xml.encoding).to match(/UTF-8/)
      end
      it 'an id attribute' do
        expect(@p_xml.at_xpath('/publicObject/@id').value).to match(/^druid:ab123cd4567/)
      end
      it 'a published attribute' do
        expect(@p_xml.at_xpath('/publicObject/@published').value).to eq(@now.xmlschema)
      end
      it 'a published version' do
        expect(@p_xml.at_xpath('/publicObject/@publishVersion').value).to eq('dor-services/' + Dor::VERSION)
      end
      it 'identityMetadata' do
        expect(@p_xml.at_xpath('/publicObject/identityMetadata')).to be
      end
      it 'contentMetadata' do
        expect(@p_xml.at_xpath('/publicObject/contentMetadata')).to be
      end
      it 'rightsMetadata' do
        expect(@p_xml.at_xpath('/publicObject/rightsMetadata')).to be
      end
      it 'generated dublin core' do
        expect(@p_xml.at_xpath('/publicObject/oai_dc:dc', 'oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/')).to be
      end

      it 'relationships' do
        ns = { 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'hydra' => 'http://projecthydra.org/ns/relations#',
               'fedora' => 'info:fedora/fedora-system:def/relations-external#', 'fedora-model' => 'info:fedora/fedora-system:def/model#' }
        expect(@p_xml.at_xpath('/publicObject/rdf:RDF', ns)).to be
        expect(@p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOf', ns)).to be
        expect(@p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOfCollection', ns)).to be
        expect(@p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora-model:hasModel', ns)).not_to be
        expect(@p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/hydra:isGovernedBy', ns)).not_to be
      end

      it 'clones of the content of the other datastreams, keeping the originals in tact' do
        expect(@item.datastreams['identityMetadata'].ng_xml.at_xpath('/identityMetadata')).to be
        expect(@item.datastreams['contentMetadata'].ng_xml.at_xpath('/contentMetadata')).to be
        expect(@item.datastreams['rightsMetadata'].ng_xml.at_xpath('/rightsMetadata')).to be
        expect(@item.datastreams['RELS-EXT'].content).to be_equivalent_to @rels
      end

      it 'an encoding of UTF-8' do
        @p_xml.encoding.should =~ /UTF-8/
      end

      it 'an id attribute' do
        @p_xml.at_xpath('/publicObject/@id').value.should =~ /^druid:ab123cd4567/
      end

      it 'a published attribute' do
        @p_xml.at_xpath('/publicObject/@published').value.should == @now.xmlschema
      end

      it 'a published version' do
        expect(@p_xml.at_xpath('/publicObject/@publishVersion').value).to eq('dor-services/' + Dor::VERSION)
      end

      it 'identityMetadata' do
        @p_xml.at_xpath('/publicObject/identityMetadata').should be
      end

      it 'contentMetadata' do
        @p_xml.at_xpath('/publicObject/contentMetadata').should be
      end

      it 'rightsMetadata' do
        @p_xml.at_xpath('/publicObject/rightsMetadata').should be
      end

      it 'generated dublin core' do
        @p_xml.at_xpath('/publicObject/oai_dc:dc', 'oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/').should be
      end

      it 'relationships' do
        ns = { 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'hydra' => 'http://projecthydra.org/ns/relations#',
               'fedora' => 'info:fedora/fedora-system:def/relations-external#', 'fedora-model' => 'info:fedora/fedora-system:def/model#' }
        @p_xml.at_xpath('/publicObject/rdf:RDF', ns).should be
        @p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOf', ns).should be
        @p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOfCollection', ns).should be
        @p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora-model:hasModel', ns).should_not be
        @p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/hydra:isGovernedBy', ns).should_not be
      end

      it 'clones of the content of the other datastreams, keeping the originals in tact' do
        @item.datastreams['identityMetadata'].ng_xml.at_xpath('/identityMetadata').should be
        @item.datastreams['contentMetadata'].ng_xml.at_xpath('/contentMetadata').should be
        @item.datastreams['rightsMetadata'].ng_xml.at_xpath('/rightsMetadata').should be
        @item.datastreams['RELS-EXT'].content.should be_equivalent_to @rels
      end

      it 'does not include a releaseData element when there are no release tags' do
        expect(@p_xml.at_xpath('/publicObject/releaseData')).to be nil
      end

      it 'does include a releaseData element when there is content inside it' do
        # Fake a tag with at least one children
        releaseData = '<releaseData><release>foo</release></releaseData>'
        allow(@item).to receive(:generate_release_xml).and_return(releaseData)
        p_xml = Nokogiri::XML(@item.public_xml)
        expect(p_xml.at_xpath('/publicObject/releaseData')).to be
      end

      it 'does not include a release element in the identityMetadata' do
        @item.datastreams['identityMetadata'].ng_xml = "<identityMetadata><release displayType=\"file\" release=\"true\" to=\"Searchworks\" what=\"collection\" when=\"2015-09-02T19:12:23Z\" who=\"laneymcg\">true</release></identityMetadata>"
        p_xml = Nokogiri::XML(@item.public_xml)
        expect(p_xml.at_xpath('/publicObject/identityMetadata/release')).to be nil
      end
    end

    describe '#publish_metadata' do
      context 'with no world discover access in rightsMetadata' do
        let(:purl_root) { Dir.mktmpdir }

        before(:each) do
          @item.rightsMetadata.content = <<-EOXML
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

          Dor::Config.push! { |config| config.stacks.local_document_cache_root purl_root }
        end

        after(:each) do
          FileUtils.remove_entry purl_root
          Dor::Config.pop!
        end

        it 'does not publish the object' do
          Dor::DigitalStacksService.should_not_receive(:transfer_to_document_store)
          @item.publish_metadata
        end

        it "removes the item's content from the Purl document cache" do
          # create druid tree and content in purl root
          druid1 = DruidTools::Druid.new @item.pid, purl_root
          druid1.mkdir
          File.open(File.join(druid1.path, 'tmpfile'), 'w') { |f| f.write 'junk' }
          @item.publish_metadata
          expect(File).to_not exist(druid1.path)
        end
      end

      context 'copies to the document cache' do
        before(:each) do
          Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123cd4567', /<identityMetadata/, 'identityMetadata')
          Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123cd4567', /<contentMetadata/, 'contentMetadata')
          Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123cd4567', /<rightsMetadata/, 'rightsMetadata')
          Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123cd4567', /<oai_dc:dc/, 'dc')
          Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123cd4567', /<publicObject/, 'public')
          Dor::DigitalStacksService.should_receive(:transfer_to_document_store).with('druid:ab123cd4567', /<mods:mods/, 'mods')
        end

        it 'identityMetadata, contentMetadata, rightsMetadata, generated dublin core, and public xml' do
          @item.rightsMetadata.content = "<rightsMetadata><access type='discover'><machine><world/></machine></access></rightsMetadata>"
          @item.publish_metadata
        end

        it 'even when rightsMetadata uses xml namespaces' do
          @item.rightsMetadata.content = %q(<rightsMetadata xmlns="http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1"><access type='discover'><machine><world/></machine></access></rightsMetadata>)
          @item.publish_metadata
        end
      end
    end

    context 'error handling' do
      it 'throws an exception if any of the required datastreams are missing' do
        pending
      end
    end
  end
  describe 'publish remotely' do
    before(:each) do
      Dor::Config.push! { |config| config.dor_services.url 'https://lyberservices-test.stanford.edu/dor' }

      RestClient::Resource.any_instance.stub(:post)
    end
    it 'should hit the correct url' do
      @item.publish_metadata_remotely.should == 'https://lyberservices-test.stanford.edu/dor/v1/objects/druid:ab123cd4567/publish'
    end
  end
end
