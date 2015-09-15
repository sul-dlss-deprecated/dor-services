require 'spec_helper'
require 'fakeweb'

require 'dor/utils/sdr_client'

describe Sdr::Client do

  describe '.get_current_version' do
    let(:sdr_client) { Dor::Config.sdr.rest_client }

    it 'returns the current of the object from SDR' do
      FakeWeb.register_uri(:get, "#{sdr_client.url}/objects/druid:ab123cd4567/current_version",
                           :body => '<currentVersion>2</currentVersion>')
      expect(Sdr::Client.current_version('druid:ab123cd4567')).to eq 2
    end

    context 'raises an exception if the xml' do

      it 'has the wrong root element' do
        FakeWeb.register_uri(:get, "#{sdr_client.url}/objects/druid:ab123cd4567/current_version",
                             :body => '<wrongRoot>2</wrongRoot>')
        expect{ Sdr::Client.current_version('druid:ab123cd4567') }.to raise_error(Exception,
                                                'Unable to parse XML from SDR current_version API call: <wrongRoot>2</wrongRoot>')
      end

      it 'does not contain an Integer as its text' do
        FakeWeb.register_uri(:get, "#{sdr_client.url}/objects/druid:ab123cd4567/current_version",
                             :body => '<currentVersion>two</currentVersion>')
        expect{ Sdr::Client.current_version('druid:ab123cd4567') }.to raise_error(Exception,
                                                'Unable to parse XML from SDR current_version API call: <currentVersion>two</currentVersion>')
      end

    end

  end

end
