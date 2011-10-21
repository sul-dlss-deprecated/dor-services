require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'dor/search_service'

describe Dor::SearchService do

  before :each do
    @mock_search = mock("RestClient::Resource")
    @mock_search.stub!(:[]).and_return(@mock_search)
    @mock_search.stub!(:options).and_return({})
    RestClient::Resource.stub!(:new).and_return(@mock_search)
    @pid = 'druid:ab123cd4567'
    @itql = Dor::SearchService::RISEARCH_TEMPLATE
  end

  context "#query_by_id" do
    it "should look up an object based on any of its IDs" do
      id = 'barcode:9191919191'
      @mock_search.should_receive(:post).with(hash_including(:query => (@itql % id))).and_return("object\ninfo:fedora/#{@pid}\n")
      result = Dor::SearchService.query_by_id(id)
      result.should have(1).things
      result.should include(@pid)
    end
  end

end
