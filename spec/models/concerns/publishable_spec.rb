# frozen_string_literal: true

require 'spec_helper'

class PublishableItem < ActiveFedora::Base
  include Dor::Identifiable
  include Dor::Publishable
  include Dor::Rightsable
  include Dor::Itemizable
end

RSpec.describe Dor::Publishable do
  before do
    Dor.configure do
      stacks do
        host 'stacks.stanford.edu'
      end
    end
  end

  let(:item) do
    instantiate_fixture('druid:ab123cd4567', PublishableItem)
  end

  it 'has a rightsMetadata datastream' do
    expect(item.datastreams['rightsMetadata']).to be_a(ActiveFedora::OmDatastream)
  end

  describe '#build_rightsMetadata_datastream' do
    let(:apo) { instantiate_fixture('druid:fg890hi1234', Dor::AdminPolicyObject) }
    let(:rights_md) { apo.defaultObjectRights.content }

    before do
      allow(item).to receive(:admin_policy_object).and_return(apo)
    end

    it 'copies the default object rights' do
      expect(item.datastreams['rightsMetadata'].ng_xml.to_s).not_to be_equivalent_to(rights_md)
      item.build_rightsMetadata_datastream(item.rightsMetadata)
      expect(item.datastreams['rightsMetadata'].ng_xml.to_s).to be_equivalent_to(rights_md)
    end
  end

  describe '#thumb' do
    before do
      expect(Deprecation).to receive(:warn)
    end
    subject { item.thumb }
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
      collection = instantiate_fixture('druid:ab123cd4567', Dor::Collection)
      expect(collection.thumb_url).to be_nil
    end

    it 'should return nil if there is no contentMetadata' do
      expect(item.thumb_url).to be_nil
    end
    it 'should find the first image as the thumb when no specific thumbs are specified' do
      item.contentMetadata.content = <<-XML
        <?xml version="1.0"?>
        <contentMetadata objectId="druid:ab123cd4567" type="image">
          <resource id="0001" sequence="1" type="image">
            <file id="ab123cd4567_05_0001.jp2" mimetype="image/jp2"/>
          </resource>
        </contentMetadata>
      XML
      expect(item.thumb_url).to eq('https://stacks.stanford.edu/image/iiif/ab123cd4567%2Fab123cd4567_05_0001/full/!400,400/0/default.jpg')
    end

    it 'should find a page resource marked as thumb with the thumb attribute when there is a resource thumb specified but not the thumb attribute' do
      item.contentMetadata.content = <<-XML
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
      expect(item.encoded_thumb).to eq('ab123cd4567%2Fab123cd4567_05_0002.jp2')
      expect(item.thumb_url).to eq('https://stacks.stanford.edu/image/iiif/ab123cd4567%2Fab123cd4567_05_0002/full/!400,400/0/default.jpg')
    end
    it 'should find an externalFile image resource when there are no other images' do
      item.contentMetadata.content = <<-XML
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
      expect(item.encoded_thumb).to eq('cg767mn6478%2F2542A.jp2')
      expect(item.thumb_url).to eq('https://stacks.stanford.edu/image/iiif/cg767mn6478%2F2542A/full/!400,400/0/default.jpg')
    end
    it 'should find an externalFile page resource when there are no other images, even if objectId attribute is missing druid prefix' do
      item.contentMetadata.content = <<-XML
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
      expect(item.encoded_thumb).to eq('cg767mn6478%2F2542A.jp2')
      expect(item.thumb_url).to eq('https://stacks.stanford.edu/image/iiif/cg767mn6478%2F2542A/full/!400,400/0/default.jpg')
    end
    it 'should find an explicit externalFile thumb resource before another image resource, and encode the space' do
      item.contentMetadata.content = <<-XML
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
      expect(item.encoded_thumb).to eq('cg767mn6478%2F2542A%20withspace.jp2')
      expect(item.thumb_url).to eq('https://stacks.stanford.edu/image/iiif/cg767mn6478%2F2542A%20withspace/full/!400,400/0/default.jpg')
    end
    it 'should return nil if no thumb is identified' do
      item.contentMetadata.content = <<-XML
        <?xml version="1.0"?>
        <contentMetadata objectId="druid:ab123cd4567" type="file">
          <resource id="0001" sequence="1" type="file">
            <file id="some_file.pdf" mimetype="file/pdf"/>
          </resource>
        </contentMetadata>
      XML
      expect(item.encoded_thumb).to be_nil
      expect(item.thumb_url).to be_nil
    end
    it 'should return nil if there is no contentMetadata datastream at all' do
      item.datastreams['contentMetadata'] = nil
      expect(item.encoded_thumb).to be_nil
      expect(item.thumb_url).to be_nil
    end
  end

  describe '#public_xml' do
    it 'delegates to PublicXmlService' do
      expect(Deprecation).to receive(:warn)
      expect_any_instance_of(Dor::PublicXmlService).to receive(:to_xml)
      item.public_xml
    end
  end

  describe '#publish_metadata' do
    it 'calls the service' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::PublishMetadataService).to receive(:publish).with(item)
      item.publish_metadata
    end
  end

  describe 'publish remotely' do
    before do
      Dor::Config.push! { |config| config.dor_services.url 'https://lyberservices-test.stanford.edu/dor' }
      stub_request(:post, 'https://lyberservices-test.stanford.edu/dor/v1/objects/druid:ab123cd4567/publish')
    end
    it 'hits the correct url' do
      expect(Deprecation).to receive(:warn)
      expect(item.publish_metadata_remotely).to be true
    end
  end
end
