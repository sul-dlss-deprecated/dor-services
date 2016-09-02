require 'spec_helper'

class PublishableItem < ActiveFedora::Base
  include Dor::Publishable
  include Dor::Processable
  include Dor::Releaseable
end

class DescribableItem < ActiveFedora::Base
  include Dor::Identifiable
  include Dor::Describable
  include Dor::Processable
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
    allow(@item).to receive(:add_collection_reference).and_return(@mods) # calls Item.find and not needed in general tests
    allow(@item).to receive(:add_constituent_relations).and_return(@mods) # calls Item.find not needed in general tests
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

  describe '#public_xml' do
    context 'there are no release tags' do
      before :each do
        expect(@item).to receive(:released_for).and_return({})
        @p_xml = Nokogiri::XML(@item.public_xml)
      end
      it 'does not include a releaseData element' do
        expect(@p_xml.at_xpath('/publicObject/releaseData')).to be_nil
      end
    end

    context 'produces xml with' do
      before(:each) do
        @now = Time.now.utc
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
        ns = {
          'rdf'          => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
          'hydra'        => 'http://projecthydra.org/ns/relations#',
          'fedora'       => 'info:fedora/fedora-system:def/relations-external#',
          'fedora-model' => 'info:fedora/fedora-system:def/model#'
        }
        expect(@p_xml.at_xpath('/publicObject/rdf:RDF', ns)).to be
        expect(@p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOf', ns)).to be
        expect(@p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOfCollection', ns)).to be
        expect(@p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isConstituentOf', ns)).to be
        expect(@p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/fedora-model:hasModel', ns)).not_to be
        expect(@p_xml.at_xpath('/publicObject/rdf:RDF/rdf:Description/hydra:isGovernedBy', ns)).not_to be
      end

      it 'clones of the content of the other datastreams, keeping the originals in tact' do
        expect(@item.datastreams['identityMetadata'].ng_xml.at_xpath('/identityMetadata')).to be
        expect(@item.datastreams['contentMetadata'].ng_xml.at_xpath('/contentMetadata')).to be
        expect(@item.datastreams['rightsMetadata'].ng_xml.at_xpath('/rightsMetadata')).to be
        expect(@item.datastreams['RELS-EXT'].content).to be_equivalent_to @rels
      end

      it 'should expand isMemberOfCollection and isConstituentOf into correct MODS' do
        allow(@item).to receive(:add_collection_reference).and_call_original
        allow(@item).to receive(:add_constituent_relations).and_call_original
        # load up collection and constituent parent items from fixture data
        expect(Dor::Item).to receive(:find).with('druid:xh235dd9059').and_return(instantiate_fixture('druid:xh235dd9059', DescribableItem))
        expect(Dor::Item).to receive(:find).with('druid:hj097bm8879').and_return(instantiate_fixture('druid:hj097bm8879', DescribableItem))

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
        expect(doc.xpath(xpath_expr, 'mods' => 'http://www.loc.gov/mods/v3').first.text.strip).to eq('Rumsey Atlas 2542')
        xpath_expr = '//mods:mods/mods:relatedItem[@type="host" and @displayLabel="Appears in"]/mods:location/mods:url'
        expect(doc.xpath(xpath_expr, 'mods' => 'http://www.loc.gov/mods/v3').first.text.strip).to match(/^http:\/\/purl.*\.stanford\.edu\/hj097bm8879$/)
      end

      it 'includes releaseData element from release tags' do
        releases = @p_xml.xpath('/publicObject/releaseData/release')
        expect(releases.map(&:inner_text)).to eq ['true', 'true']
        expect(releases.map{ |r| r['to']}).to eq ['Searchworks', 'Some_special_place']
      end

      it 'does include a releaseData element when there is content inside it' do
        releaseData = '<releaseData><release>foo</release></releaseData>'
        allow(@item).to receive(:generate_release_xml).and_return(releaseData)
        p_xml = Nokogiri::XML(@item.public_xml)
        expect(p_xml.at_xpath('/publicObject/releaseData/release').inner_text).to eq 'foo'
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

        it "removes the item's content from the Purl document cache and creates a .delete entry" do
          # create druid tree and dummy content in purl root
          druid1 = DruidTools::Druid.new @item.pid, purl_root
          druid1.mkdir
          expect(druid1.deletes_record_exists?).to be_falsey # deletes record not there yet
          File.open(File.join(druid1.path, 'tmpfile'), 'w') {|f| f.write 'junk' }
          @item.publish_metadata
          expect(File).to_not exist(druid1.path) # it should now be gone
          expect(druid1.deletes_record_exists?).to be_truthy # deletes record created
        end
      end

      it 'handles externalFile references' do
        correctPublicContentMetadata = Nokogiri::XML(read_fixture('hj097bm8879_publicObject.xml')).at_xpath('/publicObject/contentMetadata').to_xml
        @item.contentMetadata.content = read_fixture('hj097bm8879_contentMetadata.xml')

        # setup stubs for child items
        %w(cg767mn6478 jw923xn5254).each do |druid|
          child_item = ItemizableItem.new(:pid => "druid:#{druid}")

          # load child content metadata fixture
          dsid = 'contentMetadata'
          child_item.datastreams[dsid] = Dor::ContentMetadataDS.from_xml read_fixture("#{druid}_#{dsid}.xml")

          # load child DC metadata fixture and set label
          dsid = 'DC'
          child_item.datastreams[dsid] = Dor::SimpleDublinCoreDs.from_xml read_fixture("#{druid}_#{dsid}.xml")
          child_item.label = child_item.datastreams[dsid].title

          # stub out retrieval for child item
          allow(Dor::Item).to receive(:find).with(child_item.pid).and_return(child_item)
        end

        # generate publicObject XML and verify that the content metadata portion is correct
        expect(Nokogiri::XML(@item.public_xml).at_xpath('/publicObject/contentMetadata').to_xml).to be_equivalent_to(correctPublicContentMetadata)
      end

      context 'handles errors for externalFile references' do
        it 'is missing resourceId and mimetype attributes' do
          @item.contentMetadata.content = <<-EOXML
          <contentMetadata objectId="hj097bm8879" type="map">
            <resource id="hj097bm8879_1" sequence="1" type="image">
              <externalFile fileId="2542A.jp2" objectId="druid:cg767mn6478"/>
              <relationship objectId="druid:cg767mn6478" type="alsoAvailableAs"/>
            </resource>
          </contentMetadata>
          EOXML

          # generate publicObject XML and verify that the content metadata portion is invalid
          expect { Nokogiri::XML(@item.public_xml) }.to raise_error(ArgumentError)
        end

        it 'has blank resourceId attribute' do
          @item.contentMetadata.content = <<-EOXML
          <contentMetadata objectId="hj097bm8879" type="map">
            <resource id="hj097bm8879_1" sequence="1" type="image">
              <externalFile fileId="2542A.jp2" objectId="druid:cg767mn6478" resourceId=" " mimetype="image/jp2"/>
              <relationship objectId="druid:cg767mn6478" type="alsoAvailableAs"/>
            </resource>
          </contentMetadata>
          EOXML

          # generate publicObject XML and verify that the content metadata portion is invalid
          expect { Nokogiri::XML(@item.public_xml) }.to raise_error(ArgumentError)
        end

        it 'has blank fileId attribute' do
          @item.contentMetadata.content = <<-EOXML
          <contentMetadata objectId="hj097bm8879" type="map">
            <resource id="hj097bm8879_1" sequence="1" type="image">
              <externalFile fileId=" " objectId="druid:cg767mn6478" resourceId="cg767mn6478_1" mimetype="image/jp2"/>
              <relationship objectId="druid:cg767mn6478" type="alsoAvailableAs"/>
            </resource>
          </contentMetadata>
          EOXML

          # generate publicObject XML and verify that the content metadata portion is invalid
          expect { Nokogiri::XML(@item.public_xml) }.to raise_error(ArgumentError)
        end

        it 'has blank objectId attribute' do
          @item.contentMetadata.content = <<-EOXML
          <contentMetadata objectId="hj097bm8879" type="map">
            <resource id="hj097bm8879_1" sequence="1" type="image">
              <externalFile fileId="2542A.jp2" objectId=" " resourceId="cg767mn6478_1" mimetype="image/jp2"/>
              <relationship objectId="druid:cg767mn6478" type="alsoAvailableAs"/>
            </resource>
          </contentMetadata>
          EOXML

          # generate publicObject XML and verify that the content metadata portion is invalid
          expect { Nokogiri::XML(@item.public_xml) }.to raise_error(ArgumentError)
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
          expect(@item).to receive(:publish_notify_on_success).with(no_args)
        end
        it 'identityMetadta, contentMetadata, rightsMetadata, generated dublin core, and public xml' do
          @item.rightsMetadata.content = "<rightsMetadata><access type='discover'><machine><world/></machine></access></rightsMetadata>"
          @item.publish_metadata
        end
        it 'even when rightsMetadata uses xml namespaces' do
          @item.rightsMetadata.content = %q(<rightsMetadata xmlns="http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1">
            <access type='discover'><machine><world/></machine></access></rightsMetadata>)
          @item.publish_metadata
        end
      end
    end

    context 'publish_notify_on_success' do
      let(:changes_dir) { Dir.mktmpdir }
      let(:purl_root) { Dir.mktmpdir }
      let(:changes_file) { File.join(changes_dir,@item.pid.gsub('druid:','')) }
      
      before(:each) do 
        Dor::Config.push! {|config| config.stacks.local_document_cache_root purl_root}
        Dor::Config.push! {|config| config.stacks.local_recent_changes changes_dir}
      end
      
      after(:each) do
        FileUtils.remove_entry purl_root
        FileUtils.remove_entry changes_dir
        Dor::Config.pop!
      end
      
      it 'writes empty notification file' do
        expect(File).to receive(:directory?).with(changes_dir).and_return(true)
        expect(File.exists?(changes_file)).to be_falsey
        @item.publish_notify_on_success
        expect(File.exists?(changes_file)).to be_truthy
      end
      it 'writes empty notification file even when given only the base id' do
        expect(File).to receive(:directory?).with(changes_dir).and_return(true)
        allow(@item).to receive(:pid).and_return('aa111bb2222')
        expect(File.exists?(changes_file)).to be_falsey
        @item.publish_notify_on_success
        expect(File.exists?(changes_file)).to be_truthy
      end
      it 'removes any associated delete entry' do
        druid1 = DruidTools::Druid.new @item.pid, purl_root
        druid1.creates_delete_record # create a deletes record so we confirm it is removed by the publish_notify_on_success method
        expect(druid1.deletes_record_exists?).to be_truthy # confirm our deletes record is there
        @item.publish_notify_on_success
        expect(druid1.deletes_record_exists?).to be_falsey # deletes record not there anymore
        expect(File.exists?(changes_file)).to be_truthy # changes file is there
      end      
      it 'raises error if misconfigured' do
        Dor::Config.push! {|config| config.stacks.local_recent_changes nil}
        expect(File).to receive(:directory?).with(nil).and_return(false)
        expect(FileUtils).not_to receive(:touch)
        expect { @item.publish_notify_on_success }.to raise_error(ArgumentError, /Missing local_recent_changes directory/)
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
      stub_request(:any, 'https://lyberservices-test.stanford.edu/dor/v1/objects/druid:ab123cd4567/publish')
    end
    it 'should hit the correct url' do
      expect(@item.publish_metadata_remotely).to eq('https://lyberservices-test.stanford.edu/dor/v1/objects/druid:ab123cd4567/publish')
    end
  end

end
