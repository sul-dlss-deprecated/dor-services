require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'dor/registration_service'
require 'net/http'

# Example Usage
=begin
f = Dor::RegistrationService.register_object :object_type => 'item', 
  :content_model => 'googleScannedBook', 
  :admin_policy => 'druid:adm65zzz', 
  :label => 'Google : Scanned Book 12345', 
  :agreement_id => 'druid:apu999blr', 
  :source_id => { :source => 'barcode', :value => 9191919191 }, 
  :other_ids => { :catkey => '000', :uuid => '111' }, 
  :tags => ['Google Tag!','Other Google Tag!']
=end

describe Dor::RegistrationService do
  
  it "should properly register an object" do
    Dor::SuriService.stub!(:mint_id).and_return("changeme:boosh")
    Fedora::Repository.instance.stub!(:ingest).and_return(Net::HTTPCreated.new("1.1","201","Created"))
  end
  
end