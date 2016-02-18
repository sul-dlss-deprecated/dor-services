require 'spec_helper'
require 'dor/utils/sdr_client'

describe Sdr::Client do
  describe '.get_current_version' do
    let(:dor_services_url) { Dor::Config.dor_services.url }

    it 'returns the current of the object from SDR' do
      stub_request(:get, "#{dor_services_url}/sdr/objects/druid:ab123cd4567/current_version")
        .to_return(:body => '<currentVersion>2</currentVersion>')
      expect(Sdr::Client.current_version('druid:ab123cd4567')).to eq 2
    end

    context 'raises an exception if the xml' do
      it 'has the wrong root element' do
        stub_request(:get, "#{dor_services_url}/sdr/objects/druid:ab123cd4567/current_version")
          .to_return(:body => '<wrongRoot>2</wrongRoot>')
        expect{ Sdr::Client.current_version('druid:ab123cd4567') }
          .to raise_error(Exception, 'Unable to parse XML from SDR current_version API call: <wrongRoot>2</wrongRoot>')
      end

      it 'does not contain an Integer as its text' do
        stub_request(:get, "#{dor_services_url}/sdr/objects/druid:ab123cd4567/current_version")
          .to_return(:body => '<currentVersion>two</currentVersion>')
        expect{ Sdr::Client.current_version('druid:ab123cd4567') }
          .to raise_error(Exception, 'Unable to parse XML from SDR current_version API call: <currentVersion>two</currentVersion>')
      end
    end
  end
end
