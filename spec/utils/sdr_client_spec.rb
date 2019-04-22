# frozen_string_literal: true

require 'spec_helper'
require 'dor/utils/sdr_client'

RSpec.describe Sdr::Client do
  describe '.get_current_version' do
    it 'returns the current of the object from SDR' do
      stub_request(:get, described_class.client['objects/druid:ab123cd4567/current_version'].url)
        .to_return(body: '<currentVersion>2</currentVersion>')
      expect(described_class.current_version('druid:ab123cd4567')).to eq 2
    end

    context 'raises an exception if the xml' do
      it 'has the wrong root element' do
        stub_request(:get, described_class.client['objects/druid:ab123cd4567/current_version'].url)
          .to_return(body: '<wrongRoot>2</wrongRoot>')
        expect { described_class.current_version('druid:ab123cd4567') }
          .to raise_error(Exception, 'Unable to parse XML from SDR current_version API call: <wrongRoot>2</wrongRoot>')
      end

      it 'does not contain an Integer as its text' do
        stub_request(:get, described_class.client['objects/druid:ab123cd4567/current_version'].url)
          .to_return(body: '<currentVersion>two</currentVersion>')
        expect { described_class.current_version('druid:ab123cd4567') }
          .to raise_error(Exception, 'Unable to parse XML from SDR current_version API call: <currentVersion>two</currentVersion>')
      end
    end
  end

  describe '.client' do
    context 'with SDR configuration' do
      before do
        allow(Dor::Config.sdr).to receive(:url).and_return('http://example.com')
      end

      it 'is configured to use SDR' do
        expect(described_class.client.url).to eq 'http://example.com'
      end
    end

    context 'with DOR services configuration' do
      before do
        allow(Dor::Config.sdr).to receive(:url).and_return(nil)
      end

      it 'is configured to use SDR' do
        expect { Sdr::Client.client }.to raise_error 'you are using dor-services to invoke calls to dor-services-app.  Use dor-services-client instead.'
      end
    end

    context 'without any configuration' do
      before do
        allow(Dor::Config.sdr).to receive(:url).and_return(nil)
        allow(Dor::Config.dor_services).to receive(:url).and_return(nil)
      end

      it 'raises an exception' do
        expect { described_class.client }.to raise_error Dor::ParameterError
      end
    end
  end
end
