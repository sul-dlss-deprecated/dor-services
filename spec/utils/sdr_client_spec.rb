# frozen_string_literal: true

require 'spec_helper'
require 'dor/utils/sdr_client'

describe Sdr::Client do
  describe '.get_current_version' do
    it 'returns the current of the object from SDR' do
      stub_request(:get, Sdr::Client.client['objects/druid:ab123cd4567/current_version'].url)
        .to_return(body: '<currentVersion>2</currentVersion>')
      expect(Sdr::Client.current_version('druid:ab123cd4567')).to eq 2
    end

    context 'raises an exception if the xml' do
      it 'has the wrong root element' do
        stub_request(:get, Sdr::Client.client['objects/druid:ab123cd4567/current_version'].url)
          .to_return(body: '<wrongRoot>2</wrongRoot>')
        expect{ Sdr::Client.current_version('druid:ab123cd4567') }
          .to raise_error(Exception, 'Unable to parse XML from SDR current_version API call: <wrongRoot>2</wrongRoot>')
      end

      it 'does not contain an Integer as its text' do
        stub_request(:get, Sdr::Client.client['objects/druid:ab123cd4567/current_version'].url)
          .to_return(body: '<currentVersion>two</currentVersion>')
        expect{ Sdr::Client.current_version('druid:ab123cd4567') }
          .to raise_error(Exception, 'Unable to parse XML from SDR current_version API call: <currentVersion>two</currentVersion>')
      end
    end
  end

  describe '.get_sdr_metadata' do
    it 'fetches the datastream from SDR' do
      stub_request(:get, Sdr::Client.client['objects/druid:ab123cd4567/metadata/technicalMetadata.xml'].url).to_return(body: '<technicalMetadata/>')
      response = Sdr::Client.get_sdr_metadata('druid:ab123cd4567', 'technicalMetadata')
      expect(response).to eq('<technicalMetadata/>')
    end
  end

  describe '.get_signature_catalog' do
    let(:druid) { 'druid:zz000zz0000' }
    it 'fetches the signature catalog from SDR' do
      resource = Sdr::Client.client["objects/#{druid}/manifest/signatureCatalog.xml"]
      stub_request(:get, resource.url).to_return(body: '<signatureCatalog objectId="druid:zz000zz0000" versionId="0" catalogDatetime="" fileCount="0" byteCount="0" blockCount="0"/>')

      catalog = Sdr::Client.get_signature_catalog(druid)
      expect(catalog.to_xml).to match(/<signatureCatalog/)
      expect(catalog.version_id).to eq 0
    end
  end

  describe '.get_content_diff' do
    let(:druid) { 'druid:zz000zz0000' }

    it 'fetches the file inventory difference from SDR' do
      resource = Sdr::Client.client["objects/#{druid}/cm-inv-diff?subset=all"]
      stub_request(:post, resource.url).to_return(body: '<fileInventoryDifference />')

      inventory_difference = Sdr::Client.get_content_diff(druid, '')

      expect(inventory_difference.to_xml).to match(/<fileInventoryDifference/)
    end

    it 'rejects invalid subset parameters' do
      expect { Sdr::Client.get_content_diff(druid, '', 'bad') }.to raise_error Dor::ParameterError
    end
  end

  describe '.get_preserved_file_content' do
    let(:druid) { 'druid:zz000zz0000' }
    let(:filename_with_spaces) { 'filename with spaces.txt' }
    let(:item_version) { 2 }
    let(:sdr_resp_body) { 'expected response' }
    let(:sdr_resp_content_type) { 'text/plain' }

    it 'properly encodes filename and passes along the sdr response with the correct content type and status code' do
      resource = Sdr::Client.client["objects/#{druid}/content/#{URI.encode(filename_with_spaces)}?version=#{item_version}"]
      stub_request(:get, resource.url).to_return(body: sdr_resp_body, headers: { content_type: sdr_resp_content_type })
      expect(Deprecation).to receive(:warn)
      preserved_content = Sdr::Client.get_preserved_file_content(druid, filename_with_spaces, item_version)
      expect(preserved_content).to eq(sdr_resp_body)
      expect(preserved_content.body).to eq(sdr_resp_body)
      expect(preserved_content.net_http_res.content_type).to eq(sdr_resp_content_type)
      expect(preserved_content.net_http_res.code.to_i).to eq(200)
    end

    it 'passes errors through to the caller' do
      resource = Sdr::Client.client["objects/#{druid}/content/bogus_filename?version=#{item_version}"]
      stub_request(:get, resource.url).to_return(status: 404)
      expect(Deprecation).to receive(:warn)
      expect { Sdr::Client.get_preserved_file_content(druid, filename_with_spaces, item_version) }.to raise_error RestClient::ResourceNotFound
    end
  end

  describe '.client' do
    context 'with SDR configuration' do
      before do
        allow(Dor::Config.sdr).to receive(:url).and_return('http://example.com')
      end

      it 'is configured to use SDR' do
        expect(Sdr::Client.client.url).to eq 'http://example.com'
      end
    end

    context 'with DOR services configuration' do
      before do
        allow(Dor::Config.sdr).to receive(:url).and_return(nil)
      end

      it 'is configured to use SDR' do
        expect(Deprecation).to receive(:warn)
        expect(Sdr::Client.client.url).to eq Dor::Config.dor_services.rest_client['v1/sdr'].url
      end
    end

    context 'without any configuration' do
      before do
        allow(Dor::Config.sdr).to receive(:url).and_return(nil)
        allow(Dor::Config.dor_services).to receive(:url).and_return(nil)
      end

      it 'raises an exception' do
        expect { Sdr::Client.client }.to raise_error Dor::ParameterError
      end
    end
  end
end
