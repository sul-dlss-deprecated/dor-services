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

  context "#register_object" do
  
    before :each do
      @pid = 'druid:ab123cd4567'
      Dor::SuriService.stub!(:mint_id).and_return("druid:ab123cd4567")
      @mock_repo = mock(Fedora::Repository)
      @mock_repo.stub!(:ingest).and_return(Net::HTTPCreated.new("1.1","201","Created"))
      Fedora::Repository.stub!(:new).and_return(@mock_repo)
      @mock_dor_item = mock("Dor::Item")
      Dor::Item.stub!(:load_instance).and_return(@mock_dor_item)

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
      Dor::SearchService.stub!(:query_by_id).and_return([])

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
      Dor::SearchService.stub!(:query_by_id).and_return([@pid])
      lambda { Dor::RegistrationService.register_object(@params) }.should raise_error(Dor::DuplicateIdError)
    end
    
  end
    
end