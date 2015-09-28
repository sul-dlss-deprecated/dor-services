require 'spec_helper'

class PublishableItem < ActiveFedora::Base
  include Dor::Publishable
  include Dor::Processable
  include Dor::Releaseable
end

class ItemizableItem < ActiveFedora::Base
  include Dor::Itemizable
end

describe Dor::Publishable do

  before(:each) { stub_config   }
  after(:each)  { unstub_config }

  before :each do

    @item = instantiate_fixture('druid:ab123cd4567', PublishableItem)
    @apo  = instantiate_fixture('druid:fg890hi1234', Dor::AdminPolicyObject)
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

  describe '#public_xml' do
    #@item.add_tags_from_purl.stub.and_return({})

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

      it 'does not include a releaseData element when there are no release tags' do
        expect(@p_xml.at_xpath('/publicObject/releaseData')).to be nil
      end

      it 'does include a releaseData element when there is content inside it' do
        #Fake a tag with at least one children
        releaseData = '<releaseData><release>foo</release></releaseData>'
        allow(@item).to receive(:generate_release_xml).and_return(releaseData)
        p_xml = Nokogiri::XML(@item.public_xml)
        expect(p_xml.at_xpath('/publicObject/releaseData')).to be
      end
      
      it 'handles externalFile references' do
        correctContentMetadata = <<-EOXML
        <contentMetadata objectId="hj097bm8879" type="map">
         <resource id="hj097bm8879_1" sequence="1" type="image">
           <label>Image 1</label>
           <externalFile fileId="2542A.jp2" objectId="druid:cg767mn6478" resourceId="cg767mn6478_1" mimetype="image/jp2">
              <imageData width="6475" height="4747"/>
            </externalFile>
           <relationship objectId="druid:cg767mn6478" type="alsoAvailableAs"/>
         </resource>
         <resource id="hj097bm8879_2" sequence="2" thumb="yes" type="image">
           <label>Title Page: Carey's American atlas.</label>
           <externalFile fileId="2542B.jp2" objectId="druid:jw923xn5254" resourceId="jw923xn5254_1" mimetype="image/jp2">
             <imageData width="3139" height="4675"/>
           </externalFile>
           <relationship objectId="druid:jw923xn5254" type="alsoAvailableAs"/>
         </resource>
        </contentMetadata>        
        EOXML
               
        @item.contentMetadata.content = <<-EOXML
        <contentMetadata objectId="hj097bm8879" type="map">
          <resource id="hj097bm8879_1" sequence="1" type="image">
            <externalFile fileId="2542A.jp2" objectId="druid:cg767mn6478" resourceId="cg767mn6478_1" mimetype="image/jp2"/>
            <relationship objectId="druid:cg767mn6478" type="alsoAvailableAs"/>
          </resource>
          <resource id="hj097bm8879_2" sequence="2" thumb="yes" type="image">
            <externalFile fileId="2542B.jp2" objectId="druid:jw923xn5254" resourceId="jw923xn5254_1" mimetype="image/jp2"/>
            <relationship objectId="druid:jw923xn5254" type="alsoAvailableAs"/>
          </resource>
        </contentMetadata>        
        EOXML
        
        # load stubs
        %w(cg767mn6478 jw923xn5254).each do |child_druid|
          ci = ItemizableItem.new(:pid => "druid:#{child_druid}")

          dsid = 'contentMetadata'
          ds = Dor::ContentMetadataDS.from_xml read_fixture("#{ci.pid.split(':').last}_#{dsid}.xml")
          ci.datastreams[dsid] = ds

          dsid = 'DC'
          ci.datastreams['DC'] = Dor::SimpleDublinCoreDs.from_xml read_fixture("#{ci.pid.split(':').last}_#{dsid}.xml")
          ci.label = ci.datastreams['DC'].title
          allow(Dor::Item).to receive(:find).with(ci.pid).and_return(ci)
        end
        
        p_xml = Nokogiri::XML(@item.public_xml)
        expect(p_xml.at_xpath('/publicObject/contentMetadata').to_xml).to be_equivalent_to(correctContentMetadata)
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

          Dor::Config.push! {|config| config.stacks.local_document_cache_root purl_root}
        end

        after(:each) do
          FileUtils.remove_entry purl_root
          Dor::Config.pop!
        end

        it 'does not publish the object' do
          expect(Dor::DigitalStacksService).not_to receive(:transfer_to_document_store)
          @item.publish_metadata
        end

        it "removes the item's content from the Purl document cache" do
          # create druid tree and content in purl root
          druid1 = DruidTools::Druid.new @item.pid, purl_root
          druid1.mkdir
          File.open(File.join(druid1.path, 'tmpfile'), 'w') {|f| f.write 'junk' }

          @item.publish_metadata
          expect(File).to_not exist(druid1.path)
        end
      end

      context 'copies to the document cache' do
        before(:each) do
          expect(Dor::DigitalStacksService).to receive(:transfer_to_document_store).with('druid:ab123cd4567', /<identityMetadata/, 'identityMetadata')
          expect(Dor::DigitalStacksService).to receive(:transfer_to_document_store).with('druid:ab123cd4567', /<contentMetadata/, 'contentMetadata')
          expect(Dor::DigitalStacksService).to receive(:transfer_to_document_store).with('druid:ab123cd4567', /<rightsMetadata/, 'rightsMetadata')
          expect(Dor::DigitalStacksService).to receive(:transfer_to_document_store).with('druid:ab123cd4567', /<oai_dc:dc/, 'dc')
          expect(Dor::DigitalStacksService).to receive(:transfer_to_document_store).with('druid:ab123cd4567', /<publicObject/, 'public')
          expect(Dor::DigitalStacksService).to receive(:transfer_to_document_store).with('druid:ab123cd4567', /<mods:mods/, 'mods')
        end
        it 'identityMetadta, contentMetadata, rightsMetadata, generated dublin core, and public xml' do
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
        skip 'write an error handling test'
      end
    end
  end

  describe 'publish remotely' do
    before(:each) do
      Dor::Config.push! {|config| config.dor_services.url 'https://lyberservices-test.stanford.edu/dor'}
      allow_any_instance_of(RestClient::Resource).to receive(:post)
    end
    it 'should hit the correct url' do
      expect(@item.publish_metadata_remotely).to eq('https://lyberservices-test.stanford.edu/dor/v1/objects/druid:ab123cd4567/publish')
    end
  end

end
