require 'spec_helper'

describe Dor::SuriService do

  describe "an enabled SuriService" do
    before(:each) do
      Dor::Config.push! do
        suri do
          mint_ids true
          url 'http://some.suri.host:8080'
          id_namespace 'druid'
          user 'suriuser'
          pass 'suripword'
        end
      end
    end

    before(:each) do
      @my_client = double('restclient').as_null_object
      RestClient::Resource.stub(:new).and_return(@my_client)
    end

    after(:each) do
      Dor::Config.pop!
    end

    it "should mint a druid using RestClient::Resource" do
      @my_client.should_receive(:post).with("").and_return('foo')
      @my_client.should_receive(:[]).with("identifiers?quantity=1").and_return(@my_client)
      Dor::SuriService.mint_id.should == "#{Dor::Config.suri.id_namespace}:foo"
    end

    it "should mint several druids if a quantity is passed in" do
      @my_client.should_receive(:post).with("").and_return("foo\nbar\nbaz")
      @my_client.should_receive(:[]).with("identifiers?quantity=3").and_return(@my_client)
      Dor::SuriService.mint_id(3).should == ["#{Dor::Config.suri.id_namespace}:foo","#{Dor::Config.suri.id_namespace}:bar","#{Dor::Config.suri.id_namespace}:baz"]
    end

    it "should throw log an error and rethrow the exception if Connect fails." do
      e = "thrown exception"
      ex = Exception.new(e)

      @my_client.should_receive(:post).with("").and_raise(ex)

      lambda{ Dor::SuriService.mint_id }.should raise_error(Exception, "thrown exception")
    end

  end

  describe "a disabled SuriService" do
    before :all do
      Dor::Config.push! { suri.mint_ids false }
    end

    before :each do
      @mock_repo = double(Rubydora::Repository)
      if ActiveFedora::Base.respond_to? :connection_for_pid
        ActiveFedora::Base.stub(:connection_for_pid).and_return(@mock_repo)
      else
        ActiveFedora.stub_chain(:fedora,:connection).and_return(@mock_repo)
      end
    end

    after :all do
      Dor::Config.pop!
    end

    it "should mint a single ID using Fedora's getNextPid API-M service" do
      xml_response = <<-EOXML
      <?xml version="1.0" encoding="UTF-8"?>
      <pidList xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.fedora.info/definitions/1/0/management/ https://dor-test.stanford.edu:443/getNextPIDInfo.xsd">
        <pid>pid:123</pid>
      </pidList>
      EOXML
      @mock_repo.should_receive(:next_pid).with(:numPIDs => 1).and_return(xml_response)
      Dor::SuriService.mint_id.should == 'pid:123'
      Dor::Config.suri.pop
    end

    it "should mint several IDs using Fedora's getNextPid API-M service" do
      xml_response = <<-EOXML
      <?xml version="1.0" encoding="UTF-8"?>
      <pidList xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.fedora.info/definitions/1/0/management/ https://dor-test.stanford.edu:443/getNextPIDInfo.xsd">
        <pid>pid:123</pid>
        <pid>pid:456</pid>
        <pid>pid:789</pid>
      </pidList>
      EOXML
      @mock_repo.should_receive(:next_pid).with(:numPIDs => 3).and_return(xml_response)
      Dor::SuriService.mint_id(3).should == ['pid:123','pid:456','pid:789']
      Dor::Config.suri.pop
    end
  end

end
