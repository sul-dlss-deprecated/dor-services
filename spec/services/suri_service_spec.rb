# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::SuriService do
  describe 'an enabled SuriService' do
    before do
      allow(Dor::Config.suri).to receive_messages(
        mint_ids: true,
        url: 'http://some.suri.host:8080',
        id_namespace: 'druid',
        user: 'suriuser',
        pass: 'suripword'
      )
    end

    before do
      @my_client = double('restclient').as_null_object
      allow(RestClient::Resource).to receive(:new).and_return(@my_client)
    end

    it 'mints a druid using RestClient::Resource' do
      expect(@my_client).to receive(:post).with('').and_return('foo')
      expect(@my_client).to receive(:[]).with('identifiers?quantity=1').and_return(@my_client)
      expect(described_class.mint_id).to eq("#{Dor::Config.suri.id_namespace}:foo")
    end

    it 'mints several druids if a quantity is passed in' do
      expect(@my_client).to receive(:post).with('').and_return("foo\nbar\nbaz")
      expect(@my_client).to receive(:[]).with('identifiers?quantity=3').and_return(@my_client)
      expect(described_class.mint_id(3)).to eq(["#{Dor::Config.suri.id_namespace}:foo", "#{Dor::Config.suri.id_namespace}:bar", "#{Dor::Config.suri.id_namespace}:baz"])
    end

    it 'throws log an error and rethrow the exception if Connect fails.' do
      e = 'thrown exception'
      ex = Exception.new(e)
      expect(@my_client).to receive(:post).with('').and_raise(ex)
      expect { described_class.mint_id }.to raise_error(Exception, 'thrown exception')
    end
  end

  describe 'a disabled SuriService' do
    before do
      @mock_repo = instance_double(Rubydora::Repository)
      @mock_client = instance_double(Rubydora::RestApiClient)
      allow(@mock_repo).to receive(:api).and_return(@mock_client)
      allow(Dor::Config.suri).to receive(:mint_ids).and_return(false)

      if ActiveFedora::Base.respond_to?(:connection_for_pid)
        allow(ActiveFedora::Base).to receive(:connection_for_pid).and_return(@mock_repo)
      else
        ActiveFedora.stub_chain(:fedora, :connection).and_return(@mock_repo)
      end
    end

    it "mints a single ID using Fedora's getNextPid API-M service" do
      xml_response = <<-EOXML
      <?xml version="1.0" encoding="UTF-8"?>
      <pidList xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.fedora.info/definitions/1/0/management/ https://dor-test.stanford.edu:443/getNextPIDInfo.xsd">
        <pid>pid:123</pid>
      </pidList>
      EOXML
      expect(@mock_client).to receive(:next_pid).with(numPIDs: 1).and_return(xml_response)
      expect(described_class.mint_id).to eq('pid:123')
    end

    it "mints several IDs using Fedora's getNextPid API-M service" do
      xml_response = <<-EOXML
      <?xml version="1.0" encoding="UTF-8"?>
      <pidList xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.fedora.info/definitions/1/0/management/ https://dor-test.stanford.edu:443/getNextPIDInfo.xsd">
        <pid>pid:123</pid>
        <pid>pid:456</pid>
        <pid>pid:789</pid>
      </pidList>
      EOXML
      expect(@mock_client).to receive(:next_pid).with(numPIDs: 3).and_return(xml_response)
      expect(described_class.mint_id(3)).to eq(['pid:123', 'pid:456', 'pid:789'])
    end
  end
end
