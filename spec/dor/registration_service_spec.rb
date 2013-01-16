require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../foxml_helper')
require 'dor/services/registration_service'
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
      if ActiveFedora::Base.respond_to? :connection_for_pid
        ActiveFedora::Base.stub(:connection_for_pid).and_return(@mock_repo)
      else
        ActiveFedora.stub_chain(:fedora,:connection).and_return(@mock_repo)
      end
      @mock_solr = mock(RSolr::Connection).as_null_object
      Dor::SearchService.stub(:solr).and_return(@mock_solr)
      @apo  = instantiate_fixture("druid:fg890hi1234", Dor::AdminPolicyObject)

      Dor::Item.any_instance.stub(:save).and_return(true)
      
      @params = {
        :object_type => 'item', 
        :content_model => 'googleScannedBook', 
        :admin_policy => 'druid:fg890hi1234', 
        :label => 'Google : Scanned Book 12345', 
        :source_id => { :barcode => 9191919191 }, 
        :other_ids => { :catkey => '000', :uuid => '111' }, 
        :tags => ['Google : Google Tag!','Google : Other Google Tag!']
      }
    end
    
    it "should properly register an object" do
      @params[:collection] = 'druid:something'
      Dor.should_receive(:find).with('druid:fg890hi1234', :lightweight => true).and_return(@apo)
      Dor.stub(:find).and_return(nil)
      Dor::SearchService.stub!(:query_by_id).and_return([])
      Dor::Item.any_instance.should_receive(:update_index).and_return(true)

      obj = Dor::RegistrationService.register_object(@params)
      obj.pid.should == @pid
      obj.label.should == @params[:label]
      obj.identityMetadata.sourceId.should == 'barcode:9191919191'
      obj.identityMetadata.otherId.should =~ @params[:other_ids].collect { |*e| e.join(':') }
      obj.rels_ext.to_rels_ext.should be_equivalent_to <<-XML
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#" 
        xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#">
        <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
          <hydra:isGovernedBy rdf:resource="info:fedora/druid:fg890hi1234"/>
          <fedora-model:hasModel rdf:resource="info:fedora/afmodel:Dor_Item"/>
          <fedora:isMemberOf rdf:resource="info:fedora/druid:something"/>
          <fedora:isMemberOf rdf:resource="info:fedora/druid:zb871zd0767"/>
          <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:something"/>
          <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:zb871zd0767"/>
        </rdf:Description>
      </rdf:RDF>
      XML
    end
  
    it "should properly register an object even if indexing fails" do
      Dor.should_receive(:find).with('druid:fg890hi1234', :lightweight => true).and_return(@apo)
      Dor.stub(:find).and_return(nil)
      Dor::SearchService.stub!(:query_by_id).and_return([])
      Dor::Item.any_instance.stub(:update_index).and_raise("503 Service Unavailable")
      Dor.logger.should_receive(:warn).with(/failed to update solr index for druid:ab123cd4567/)
      
      obj = Dor::RegistrationService.register_object(@params)
      obj.pid.should == @pid
      obj.label.should == @params[:label]
      obj.identityMetadata.sourceId.should == 'barcode:9191919191'
      obj.identityMetadata.otherId.should =~ @params[:other_ids].collect { |*e| e.join(':') }
      obj.rels_ext.to_rels_ext.should be_equivalent_to <<-XML
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#" 
        xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#">
        <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
          <hydra:isGovernedBy rdf:resource="info:fedora/druid:fg890hi1234"/>
          <fedora-model:hasModel rdf:resource="info:fedora/afmodel:Dor_Item"/>
          <fedora:isMemberOf rdf:resource="info:fedora/druid:zb871zd0767"/>
          <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:zb871zd0767"/>
        </rdf:Description>
      </rdf:RDF>
      XML
    end
    
    it "should set rightsMetadata based on the APO default when passed rights=default" do
      @params[:rights]='default'
      Dor.should_receive(:find).with('druid:fg890hi1234', :lightweight => true).and_return(@apo)
      Dor.stub(:find).and_return(nil)
      Dor::SearchService.stub!(:query_by_id).and_return([])
      Dor::Item.any_instance.should_receive(:update_index).and_return(true)

      obj = Dor::RegistrationService.register_object(@params)
      obj.pid.should == @pid
      obj.label.should == @params[:label]
      obj.identityMetadata.sourceId.should == 'barcode:9191919191'
      obj.identityMetadata.otherId.should =~ @params[:other_ids].collect { |*e| e.join(':') }
      obj.datastreams['rightsMetadata'].ng_xml.should be_equivalent_to <<-XML
      <?xml version="1.0"?>
      <rightsMetadata>
                <copyright>
                  <human type="copyright">This work is in the Public Domain.</human>
                </copyright>
                <access type="discover">
                  <machine>
                    <world/>
                  </machine
                </access>
                <access type="read">
                  <machine>
                    <group>stanford</group>
                  </machine>
                </access>
                <use>
                  <human type="creativecommons">Attribution Share Alike license</human>
                  <machine type="creativecommons">by-sa</machine>
                </use>
              </rightsMetadata>
      XML
    end
    
    it "should set rightsMetadata based on the APO default but replace read rights to be world when passed rights=world " do
      @params[:rights]='world'
      Dor.should_receive(:find).with('druid:fg890hi1234', :lightweight => true).and_return(@apo)
      Dor.stub(:find).and_return(nil)
      Dor::SearchService.stub!(:query_by_id).and_return([])
      Dor::Item.any_instance.should_receive(:update_index).and_return(true)

      obj = Dor::RegistrationService.register_object(@params)
      obj.pid.should == @pid
      obj.label.should == @params[:label]
      obj.identityMetadata.sourceId.should == 'barcode:9191919191'
      obj.identityMetadata.otherId.should =~ @params[:other_ids].collect { |*e| e.join(':') }
      obj.datastreams['rightsMetadata'].ng_xml.should be_equivalent_to <<-XML
      <?xml version="1.0"?>
      <rightsMetadata>
                <copyright>
                  <human type="copyright">This work is in the Public Domain.</human>
                </copyright>
                <access type="discover">
                  <machine>
                    <world/>
                  </machine>
                </access>
                <access type="read">
                  <machine>
                    <world/>
                  </machine>
                </access>
                <use>
                  <human type="creativecommons">Attribution Share Alike license</human>
                  <machine type="creativecommons">by-sa</machine>
                </use>
              </rightsMetadata>
      XML
    end
  
    it "should set rightsMetadata based on the APO default but replace read rights to be world when passed rights=stanford " do
      @params[:rights]='stanford'
      Dor.should_receive(:find).with('druid:fg890hi1234', :lightweight => true).and_return(@apo)
      Dor.stub(:find).and_return(nil)
      Dor::SearchService.stub!(:query_by_id).and_return([])
      Dor::Item.any_instance.should_receive(:update_index).and_return(true)

      obj = Dor::RegistrationService.register_object(@params)
      obj.pid.should == @pid
      obj.label.should == @params[:label]
      obj.identityMetadata.sourceId.should == 'barcode:9191919191'
      obj.identityMetadata.otherId.should =~ @params[:other_ids].collect { |*e| e.join(':') }
      obj.datastreams['rightsMetadata'].ng_xml.should be_equivalent_to <<-XML
      <?xml version="1.0"?>
      <rightsMetadata>
                <copyright>
                  <human type="copyright">This work is in the Public Domain.</human>
                </copyright>
                <access type="discover">
                  <machine>
                    <world/>
                  </machine>
                </access>
                <access type="read">
                  <machine>
                  <group>Stanford</group>
                  </machine>
                </access>
                <use>
                  <human type="creativecommons">Attribution Share Alike license</human>
                  <machine type="creativecommons">by-sa</machine>
                </use>
              </rightsMetadata>
      XML
    end
    
    it "should set the descriptive metadata to basic mods using the label as title if passed metadata_source=label " do
      @params[:metadata_source]='label'
      Dor.should_receive(:find).with('druid:fg890hi1234', :lightweight => true).and_return(@apo)
      Dor.stub(:find).and_return(nil)
      Dor::SearchService.stub!(:query_by_id).and_return([])
      Dor::Item.any_instance.should_receive(:update_index).and_return(true)

      obj = Dor::RegistrationService.register_object(@params)
      obj.pid.should == @pid
      obj.label.should == @params[:label]
      obj.identityMetadata.sourceId.should == 'barcode:9191919191'
      obj.identityMetadata.otherId.should =~ @params[:other_ids].collect { |*e| e.join(':') }
      obj.datastreams['descMetadata'].ng_xml.should be_equivalent_to <<-XML
      <?xml version="1.0"?>
      <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
         <titleInfo>
            <title>Google : Scanned Book 12345</title>
         </titleInfo>
      </mods>
      XML
    end
    
    it "should raise an exception if a required parameter is missing" do
      @params.delete(:object_type)
      lambda { Dor::RegistrationService.register_object(@params) }.should raise_error(Dor::ParameterError)
    end
    
    it "should raise an exception if the label empty and metadata_source is label or none" do
      @params[:label]=''
      @params[:metadata_source]='label'
      Dor::SearchService.stub(:query_by_id).and_return([nil])
      lambda { Dor::RegistrationService.register_object(@params) }.should raise_error(Dor::ParameterError)
    end
    it "should not raise an exception if the label is empty and metadata_source is mdtoolkit" do
      @params[:label]=''
      @params[:metadata_source]='mdtoolkit'
      Dor::SearchService.stub(:query_by_id).and_return([nil])
      Dor::RegistrationService.register_object(@params)
    end
    it "should raise an exception if source_id is missing" do
      @params.delete(:source_id)
      lambda { Dor::RegistrationService.register_object(@params) }.should raise_error(Dor::ParameterError)
    end
    
    it "should raise an exception if registering a duplicate PID" do
      @params[:pid] = @pid
      Dor::SearchService.should_receive(:query_by_id).with('druid:ab123cd4567').and_return([@pid])
      lambda { Dor::RegistrationService.register_object(@params) }.should raise_error(Dor::DuplicateIdError)
    end
    
    it "should raise an exception if the label is longer than 255 chars" do
      Dor::SearchService.stub!(:query_by_id).and_return([])
      @params[:label]='a'*256
      obj= Dor::RegistrationService.register_object(@params)
      obj.label.should=='a'*254
    end
    it "should raise an exception if registering a duplicate source ID" do
      Dor::SearchService.should_receive(:query_by_id).with('barcode:9191919191').and_return([@pid])
      lambda { Dor::RegistrationService.register_object(@params) }.should raise_error(Dor::DuplicateIdError)
    end
  end
end
