require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'dor/registration_service'
require 'net/http'

# Example Usage
=begin
Dor::RegistrationService.register_object :object_type => 'item', 
  :content_model => 'googleScannedBook', 
  :admin_policy => 'druid:adm65zzz', 
  :label => 'Google : Scanned Book 12345', 
  :agreement_id => 'druid:apu999blr', 
  :source_id => { :barcode => 9191919191 }, 
  :other_ids => { :catkey => '000', :uuid => '111' }, 
  :tags => ['Google Tag!','Other Google Tag!']
=end

describe Dor::RegistrationService do

  before :each do
    @mock_search = mock("RestClient::Resource")
    @mock_search.stub!(:[]).and_return(@mock_search)
    RestClient::Resource.stub!(:new).and_return(@mock_search)
    @pid = 'druid:abc123def'
    @itql = Dor::RegistrationService::RISEARCH_TEMPLATE
  end
  
  context "#register_object" do
  
    before :each do
      Dor::SuriService.stub!(:mint_id).and_return("druid:abc123def")
      Fedora::Repository.instance.stub!(:ingest).and_return(Net::HTTPCreated.new("1.1","201","Created"))
      @mock_dor_base = mock("Dor::Base")
      Dor::Base.stub!(:load_instance).and_return(@mock_dor_base)

      @params = {
        :object_type => 'item', 
        :content_model => 'googleScannedBook', 
        :admin_policy => 'druid:adm65zzz', 
        :label => 'Google : Scanned Book 12345', 
        :agreement_id => 'druid:apu999blr', 
        :source_id => { :barcode => 9191919191 }, 
        :other_ids => { :catkey => '000', :uuid => '111' }, 
        :tags => ['Google Tag!','Other Google Tag!']
      }
    end
    
    it "should properly register an object" do
      @mock_search.should_receive(:post).once.and_return("object\n")

      obj = Dor::RegistrationService.register_object(@params)
      obj[:response].code.should == '201'
      obj[:response].message.should == 'Created'
      obj[:pid].should == @pid
    end
  
    it "should raise an exception if a required parameter is missing" do
      @params.delete(:object_type)
      lambda { Dor::RegistrationService.register_object(@params) }.should raise_error(Dor::ParameterError)
    end
    
    it "should raise an exception if registering a duplicate PID" do
      @params[:pid] = @pid
      @mock_search.should_receive(:post).with(hash_including(:query => (@itql % @pid))).and_return("object\ninfo:fedora/#{@pid}\n")
      lambda { Dor::RegistrationService.register_object(@params) }.should raise_error(Dor::DuplicateIdError)
    end
    
  end
  
  context "#query_by_id" do
    it "should look up an object based on any of its IDs" do
      id = 'barcode:9191919191'
      @mock_search.should_receive(:post).with(hash_including(:query => (@itql % id))).and_return("object\ninfo:fedora/#{@pid}\n")
      result = Dor::RegistrationService.query_by_id(id)
      result.should have(1).things
      result.should include(@pid)
    end
  end
  
end