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
  :source_id => { :source => 'barcode', :value => 9191919191 }, 
  :other_ids => { :catkey => '000', :uuid => '111' }, 
  :tags => ['Google Tag!','Other Google Tag!']
=end

describe Dor::RegistrationService do
  
  context "#register_object" do
  
    before :each do
      Dor::SuriService.stub!(:mint_id).and_return("druid:abc123def")
      Fedora::Repository.instance.stub!(:ingest).and_return(Net::HTTPCreated.new("1.1","201","Created"))
      @mock_solr = mock("Solr::Connection")
      Solr::Connection.stub!(:new).and_return(@mock_solr)
      @mock_dor_base = mock("Dor::Base")
      Dor::Base.stub!(:load_instance).and_return(@mock_dor_base)

      @pid = 'druid:abc123def'
      @params = {
        :object_type => 'item', 
        :content_model => 'googleScannedBook', 
        :admin_policy => 'druid:adm65zzz', 
        :label => 'Google : Scanned Book 12345', 
        :agreement_id => 'druid:apu999blr', 
        :source_id => { :source => 'barcode', :value => 9191919191 }, 
        :other_ids => { :catkey => '000', :uuid => '111' }, 
        :tags => ['Google Tag!','Other Google Tag!']
      }
    end
    
    it "should properly register an object" do
      @mock_solr.should_receive(:query).exactly(3).times.and_return([])

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
      @mock_solr.should_receive(:query).with(/#{@pid}/).and_return([{ 'PID'=>@pid }])
      lambda { Dor::RegistrationService.register_object(@params) }.should raise_error(Dor::DuplicateIdError)
    end
    
  end
  
  context "#query_by_id" do
    it "should look up an object based on any of its IDs" do
      mock_solr = mock("Solr::Connection")
      mock_solr.should_receive(:query).and_return([{'PID' => @pid}])
      Solr::Connection.stub!(:new).and_return(mock_solr)
    
      result = Dor::RegistrationService.query_by_id('barcode:9191919191')
      result.should have(1).things
      result.should include(@pid)
    end
  end
  
end