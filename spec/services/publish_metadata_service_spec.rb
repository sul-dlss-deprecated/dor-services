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

RSpec.describe Dor::PublishMetadataService do
  before { stub_config }
  after { unstub_config }

  let(:item) do
    instantiate_fixture('druid:ab123cd4567', PublishableItem).tap do |i|
      i.contentMetadata.content = '<contentMetadata/>'
      i.rels_ext.content = rels
    end
  end
  let(:service) { described_class.new(item) }

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

  describe '#publish' do
    before do
      allow(OpenURI).to receive(:open_uri).with('https://purl-test.stanford.edu/ab123cd4567.xml').and_return('<xml/>')
    end

    context 'with no world discover access in rightsMetadata' do
      let(:purl_root) { Dir.mktmpdir }

      before do
        item.rightsMetadata.content = <<-EOXML
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

        Dor::Config.push! do |config|
          config.stacks.local_document_cache_root purl_root
          config.purl_services.url 'http://example.com/purl'
        end

        stub_request(:delete, 'example.com/purl/purls/ab123cd4567')
      end

      after(:each) do
        FileUtils.remove_entry purl_root
        Dor::Config.pop!
      end

      it 'does not publish the object' do
        expect(Dor::DigitalStacksService).not_to receive(:transfer_to_document_store)
        service.publish
      end

      it 'notifies the purl service of the deletion' do
        service.publish
        expect(WebMock).to have_requested(:delete, 'example.com/purl/purls/ab123cd4567')
      end

      it "removes the item's content from the Purl document cache and creates a .delete entry" do
        # create druid tree and dummy content in purl root
        druid1 = DruidTools::Druid.new item.pid, purl_root
        druid1.mkdir
        expect(druid1.deletes_record_exists?).to be_falsey # deletes record not there yet
        File.open(File.join(druid1.path, 'tmpfile'), 'w') { |f| f.write 'junk' }
        service.publish
        expect(File).to_not exist(druid1.path) # it should now be gone
        expect(druid1.deletes_record_exists?).to be_truthy # deletes record created
      end
    end

    context 'copies to the document cache' do
      let(:mods) do
        <<-EOXML
          <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                     version="3.3"
                     xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd">
            <mods:identifier type="local" displayLabel="SUL Resource ID">druid:ab123cd4567</mods:identifier>
          </mods:mods>
        EOXML
      end
      let(:md_service) { instance_double(Dor::PublicDescMetadataService, to_xml: mods, ng_xml: Nokogiri::XML(mods)) }
      let(:dc_service) { instance_double(Dor::DublinCoreService, ng_xml: Nokogiri::XML('<oai_dc:dc></oai_dc:dc>')) }
      let(:public_service) { instance_double(Dor::PublicXmlService, to_xml: '<publicObject></publicObject>') }

      before do
        allow(Dor::DublinCoreService).to receive(:new).and_return(dc_service)
        allow(Dor::PublicXmlService).to receive(:new).and_return(public_service)
        allow(Dor::PublicDescMetadataService).to receive(:new).and_return(md_service)
      end

      context 'with an item' do
        before do
          expect_any_instance_of(Dor::PublishMetadataService).to receive(:transfer_to_document_store).with(/<identityMetadata/, 'identityMetadata')
          expect_any_instance_of(Dor::PublishMetadataService).to receive(:transfer_to_document_store).with(/<contentMetadata/, 'contentMetadata')
          expect_any_instance_of(Dor::PublishMetadataService).to receive(:transfer_to_document_store).with(/<rightsMetadata/, 'rightsMetadata')
          expect_any_instance_of(Dor::PublishMetadataService).to receive(:transfer_to_document_store).with(/<oai_dc:dc/, 'dc')
          expect_any_instance_of(Dor::PublishMetadataService).to receive(:transfer_to_document_store).with(/<publicObject/, 'public')
          expect_any_instance_of(Dor::PublishMetadataService).to receive(:transfer_to_document_store).with(/<mods:mods/, 'mods')
          expect_any_instance_of(Dor::PublishMetadataService).to receive(:publish_notify_on_success).with(no_args)
        end

        it 'identityMetadta, contentMetadata, rightsMetadata, generated dublin core, and public xml' do
          item.rightsMetadata.content = "<rightsMetadata><access type='discover'><machine><world/></machine></access></rightsMetadata>"
          service.publish
          expect(Dor::DublinCoreService).to have_received(:new).with(item)
          expect(Dor::PublicXmlService).to have_received(:new).with(item)
          expect(Dor::PublicDescMetadataService).to have_received(:new).with(item)
        end

        it 'even when rightsMetadata uses xml namespaces' do
          item.rightsMetadata.content = %q(<rightsMetadata xmlns="http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1">
            <access type='discover'><machine><world/></machine></access></rightsMetadata>)
          service.publish
        end
      end

      context 'with a collection object' do
        let(:item) { instantiate_fixture('druid:ab123cd4567', Dor::Collection) }

        before do
          item.descMetadata.content = mods
          item.rightsMetadata.content = "<rightsMetadata><access type='discover'><machine><world/></machine></access></rightsMetadata>"
          item.rels_ext.content = rels
        end

        before do
          expect_any_instance_of(Dor::PublishMetadataService).to receive(:transfer_to_document_store).with(/<identityMetadata/, 'identityMetadata')
          expect_any_instance_of(Dor::PublishMetadataService).not_to receive(:transfer_to_document_store).with(/<contentMetadata/, 'contentMetadata')
          expect_any_instance_of(Dor::PublishMetadataService).to receive(:transfer_to_document_store).with(/<rightsMetadata/, 'rightsMetadata')
          expect_any_instance_of(Dor::PublishMetadataService).to receive(:transfer_to_document_store).with(/<oai_dc:dc/, 'dc')
          expect_any_instance_of(Dor::PublishMetadataService).to receive(:transfer_to_document_store).with(/<publicObject/, 'public')
          expect_any_instance_of(Dor::PublishMetadataService).to receive(:transfer_to_document_store).with(/<mods:mods/, 'mods')
          expect_any_instance_of(Dor::PublishMetadataService).to receive(:publish_notify_on_success).with(no_args)
        end

        it 'ignores missing data' do
          service.publish
        end
      end
    end
  end

  describe '#publish_notify_on_success' do
    subject(:notify) { service.send(:publish_notify_on_success) }

    context 'when purl-fetcher is configured' do
      before do
        Dor::Config.push! do |config|
          config.purl_services.url 'http://example.com/purl'
        end
        stub_request(:post, 'example.com/purl/purls/ab123cd4567')
      end
      it 'notifies the purl service of the update' do
        notify
        expect(WebMock).to have_requested(:post, 'example.com/purl/purls/ab123cd4567')
      end
    end

    context 'when purl-fetcher is not configured' do
      let(:purl_root) { Dir.mktmpdir }
      let(:changes_dir) { Dir.mktmpdir }
      let(:changes_file) { File.join(changes_dir, item.pid.gsub('druid:', '')) }

      before do
        expect(Deprecation).to receive(:warn)
        Dor::Config.push! { |config| config.stacks.local_document_cache_root purl_root }
        Dor::Config.push! { |config| config.stacks.local_recent_changes changes_dir }
      end

      after do
        FileUtils.remove_entry purl_root
        FileUtils.remove_entry changes_dir
        Dor::Config.pop!
      end

      it 'writes empty notification file' do
        expect(File).to receive(:directory?).with(changes_dir).and_return(true)
        expect(File.exist?(changes_file)).to be_falsey
        notify
        expect(File.exist?(changes_file)).to be_truthy
      end

      it 'writes empty notification file even when given only the base id' do
        expect(File).to receive(:directory?).with(changes_dir).and_return(true)
        allow(item).to receive(:pid).and_return('aa111bb2222')
        expect(File.exist?(changes_file)).to be_falsey
        notify
        expect(File.exist?(changes_file)).to be_truthy
      end

      it 'removes any associated delete entry' do
        druid1 = DruidTools::Druid.new item.pid, purl_root
        druid1.creates_delete_record # create a deletes record so we confirm it is removed by the publish_notify_on_success method
        expect(druid1.deletes_record_exists?).to be_truthy # confirm our deletes record is there
        notify
        expect(druid1.deletes_record_exists?).to be_falsey # deletes record not there anymore
        expect(File.exist?(changes_file)).to be_truthy # changes file is there
      end

      it 'does not explode if the deletes entry cannot be removed' do
        druid1 = DruidTools::Druid.new item.pid, purl_root
        druid1.creates_delete_record # create a deletes record
        expect(druid1.deletes_record_exists?).to be_truthy # confirm our deletes record is there
        allow(FileUtils).to receive(:rm).and_raise(Errno::EACCES) # prevent the deletes method from running
        expect(Dor.logger).to receive(:warn).with("Access denied while trying to remove .deletes file for #{item.pid}") # we will get a warning
        notify
        expect(druid1.deletes_record_exists?).to be_truthy # deletes record is still there since it cannot be removed
        expect(File.exist?(changes_file)).to be_truthy # changes file is there
      end

      it 'raises error if misconfigured' do
        Dor::Config.push! { |config| config.stacks.local_recent_changes nil }
        expect(File).to receive(:directory?).with(nil).and_return(false)
        expect(FileUtils).not_to receive(:touch)
        expect { notify }.to raise_error(ArgumentError, /Missing local_recent_changes directory/)
      end
    end
  end

  describe '#transfer_to_document_store' do
    let(:purl_root) { Dir.mktmpdir }
    let(:stacks_root) { Dir.mktmpdir }
    let(:workspace_root) { Dir.mktmpdir }

    before do
      Dor::Config.push! { |c| c.stacks.local_document_cache_root purl_root }
      # Dor::Config.push! { |c| c.stacks.local_stacks_root stacks_root }
      Dor::Config.push! { |c| c.stacks.local_workspace_root workspace_root }
    end

    after do
      FileUtils.remove_entry purl_root
      # FileUtils.remove_entry stacks_root
      FileUtils.remove_entry workspace_root
      Dor::Config.pop!
    end

    it 'copies the given metadata to the document cache in the Digital Stacks' do
      dr = DruidTools::PurlDruid.new item.pid, purl_root
      service.send(:transfer_to_document_store, '<xml/>', 'someMd')
      file_path = dr.find(:content, 'someMd')
      expect(file_path).to match(%r{4567/someMd$})
      expect(IO.read(file_path)).to eq('<xml/>')
    end
  end
end
