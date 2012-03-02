require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../foxml_helper')
require 'dor/registration_service'
require 'net/http'

describe Dor::RegistrationService do

  context "#register_object" do
  
    before :all do
      stub_config
    end
    
    after :all do
      unstub_config
    end
    
    before :each do
      @pid = 'druid:ab123cd4567'
      Dor::SuriService.stub!(:mint_id).and_return("druid:ab123cd4567")
      @mock_repo = mock(Rubydora::Repository).as_null_object
      ActiveFedora.stub_chain(:fedora,:connection).and_return(@mock_repo)
      @mock_solr = mock(Solr::Connection).as_null_object
      ActiveFedora.stub_chain(:solr,:conn).and_return(@mock_solr)
      @apo  = instantiate_fixture("druid:fg890hi1234", Dor::AdminPolicyObject)

      ActiveFedora::Base.class_eval {
        alias_method :_save, :save
        def save; true; end
      }
      
      @params = {
        :object_type => 'item', 
        :content_model => 'googleScannedBook', 
        :admin_policy => 'druid:fg890hi1234', 
        :label => 'Google : Scanned Book 12345', 
        :agreement_id => 'druid:apu999blr', 
        :source_id => { :barcode => 9191919191 }, 
        :other_ids => { :catkey => '000', :uuid => '111' }, 
        :tags => ['Google : Google Tag!','Google : Other Google Tag!']
      }
    end
    
    after :each do
      ActiveFedora::Base.class_eval {
        alias_method :save, :_save
        remove_method :_save
      }
    end
    
    it "should properly register an object" do
      Dor.should_receive(:find).with('druid:fg890hi1234', :lightweight => true).and_return(@apo)
      Dor.stub(:find).and_return(nil)
      Dor::SearchService.stub!(:query_by_id).and_return([])

      obj = Dor::RegistrationService.register_object(@params)
      obj.pid.should == @pid
      obj.label.should == @params[:label]
      obj.identityMetadata.sourceId.should == 'barcode:9191919191'
      obj.identityMetadata.otherId.should =~ @params[:other_ids].collect { |*e| e.join(':') }
      obj.rels_ext.to_xml(true).should be_equivalent_to <<-XML
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#">
        <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
          <fedora-model:hasModel rdf:resource="info:fedora/afmodel:Dor_Item"/>
          <fedora:isMemberOf rdf:resource="info:fedora/druid:zb871zd0767"/>
          <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:zb871zd0767"/>
        </rdf:Description>
      </rdf:RDF>
      XML
    end
  
    it "should raise an exception if a required parameter is missing" do
      @params.delete(:object_type)
      lambda { Dor::RegistrationService.register_object(@params) }.should raise_error(Dor::ParameterError)
    end
    
    it "should raise an exception if registering a duplicate PID" do
      @params[:pid] = @pid
      Dor::SearchService.should_receive(:query_by_id).with('druid:ab123cd4567').and_return([@pid])
      lambda { Dor::RegistrationService.register_object(@params) }.should raise_error(Dor::DuplicateIdError)
    end

    it "should raise an exception if registering a duplicate source ID" do
      Dor::SearchService.should_receive(:query_by_id).with('barcode:9191919191').and_return([@pid])
      lambda { Dor::RegistrationService.register_object(@params) }.should raise_error(Dor::DuplicateIdError)
    end
  end
    
end