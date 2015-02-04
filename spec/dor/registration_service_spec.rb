require 'spec_helper'
require 'net/http'

describe Dor::RegistrationService do

  context "#register_object" do

    before(:each) { stub_config }
    after(:each)  { unstub_config }

    before :each do
      @pid = 'druid:ab123cd4567'
      allow(Dor::SuriService).to receive(:mint_id).and_return("druid:ab123cd4567")
      @mock_repo = double(Rubydora::Repository).as_null_object
      if ActiveFedora::Base.respond_to?(:connection_for_pid)
        allow(ActiveFedora::Base).to receive(:connection_for_pid).and_return(@mock_repo)
      else
        ActiveFedora.stub_chain(:fedora,:connection).and_return(@mock_repo)
      end
      @mock_solr = double(RSolr::Connection).as_null_object
      allow(Dor::SearchService).to receive(:solr).and_return(@mock_solr)
      @apo  = instantiate_fixture("druid:fg890hi1234", Dor::AdminPolicyObject)
      allow(@apo).to receive(:new_record?).and_return false

      allow_any_instance_of(Dor::Item).to receive(:save).and_return(true)
      allow_any_instance_of(Dor::Collection).to receive(:save).and_return(true)

      allow(Dor).to receive(:find).with('druid:fg890hi1234', :lightweight => true).and_return(@apo)

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

    let(:mock_collection) {
      coll = Dor::Collection.new
      allow(coll).to receive(:new?).and_return false
      allow(coll).to receive(:new_record?).and_return false
      allow(coll).to receive(:pid).and_return 'druid:something'
      allow(coll).to receive(:save)
      coll
    }

    it "should properly register an object" do
      @params[:collection] = 'druid:something'
      expect(Dor::Collection).to receive(:find).with('druid:something').and_return(mock_collection)
      allow(Dor::SearchService).to receive(:query_by_id).and_return([])
      expect_any_instance_of(Dor::Item).to receive(:update_index).and_return(true)

      obj = Dor::RegistrationService.register_object(@params)
      expect(obj.pid).to eq(@pid)
      expect(obj.label).to eq(@params[:label])
      expect(obj.identityMetadata.sourceId).to eq('barcode:9191919191')
      expect(obj.identityMetadata.otherId).to match_array(@params[:other_ids].collect { |*e| e.join(':') })
      expect(obj.datastreams['RELS-EXT'].to_rels_ext).to be_equivalent_to <<-XML
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
      allow(Dor::SearchService).to receive(:query_by_id).and_return([])
      allow_any_instance_of(Dor::Item).to receive(:update_index).and_raise("503 Service Unavailable")
      expect(Dor.logger).to receive(:warn).with(/failed to update solr index for druid:ab123cd4567/)

      obj = Dor::RegistrationService.register_object(@params)
      expect(obj.pid).to eq(@pid)
      expect(obj.label).to eq(@params[:label])
      expect(obj.identityMetadata.sourceId).to eq('barcode:9191919191')
      expect(obj.identityMetadata.otherId).to match_array(@params[:other_ids].collect { |*e| e.join(':') })
      expect(obj.rels_ext.to_rels_ext).to be_equivalent_to <<-XML
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
      allow(Dor::SearchService).to receive(:query_by_id).and_return([])
      expect_any_instance_of(Dor::Item).to receive(:update_index).and_return(true)

      obj = Dor::RegistrationService.register_object(@params)
      expect(obj.pid).to eq(@pid)
      expect(obj.label).to eq(@params[:label])
      expect(obj.identityMetadata.sourceId).to eq('barcode:9191919191')
      expect(obj.identityMetadata.otherId).to match_array(@params[:other_ids].collect { |*e| e.join(':') })
      expect(obj.datastreams['rightsMetadata'].ng_xml).to be_equivalent_to <<-XML
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
      allow(Dor::SearchService).to receive(:query_by_id).and_return([])
      expect_any_instance_of(Dor::Item).to receive(:update_index).and_return(true)

      obj = Dor::RegistrationService.register_object(@params)
      expect(obj.pid).to eq(@pid)
      expect(obj.label).to eq(@params[:label])
      expect(obj.identityMetadata.sourceId).to eq('barcode:9191919191')
      expect(obj.identityMetadata.otherId).to match_array(@params[:other_ids].collect { |*e| e.join(':') })
      expect(obj.datastreams['rightsMetadata'].ng_xml).to be_equivalent_to <<-XML
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
    it "should set rightsMetadata based on the APO default but replace read rights to be world when passed rights=world " do
      @params[:rights]='world'
      allow(Dor::SearchService).to receive(:query_by_id).and_return([])
      expect_any_instance_of(Dor::Item).to receive(:update_index).and_return(true)

      obj = Dor::RegistrationService.register_object(@params)
      expect(obj.pid).to eq(@pid)
      expect(obj.label).to eq(@params[:label])
      expect(obj.identityMetadata.sourceId).to eq('barcode:9191919191')
      expect(obj.identityMetadata.otherId).to match_array(@params[:other_ids].collect { |*e| e.join(':') })
      expect(obj.datastreams['rightsMetadata'].ng_xml).to be_equivalent_to <<-XML
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

    it "should set rightsMetadata based on the APO default but replace read rights even if it is a collection" do
      @params[:rights]='stanford'
      @params[:object_type]='collection'
      allow(Dor::SearchService).to receive(:query_by_id).and_return([])
      expect_any_instance_of(Dor::Collection).to receive(:update_index).and_return(true)

      obj = Dor::RegistrationService.register_object(@params)
      expect(obj.pid).to eq(@pid)
      expect(obj.label).to eq(@params[:label])
      expect(obj.identityMetadata.sourceId).to eq('barcode:9191919191')
      expect(obj.identityMetadata.otherId).to match_array(@params[:other_ids].collect { |*e| e.join(':') })
      expect(obj.datastreams['rightsMetadata'].ng_xml).to be_equivalent_to <<-XML
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
      allow(Dor::SearchService).to receive(:query_by_id).and_return([])
      expect_any_instance_of(Dor::Item).to receive(:update_index).and_return(true)

      obj = Dor::RegistrationService.register_object(@params)
      expect(obj.pid).to eq(@pid)
      expect(obj.label).to eq(@params[:label])
      expect(obj.identityMetadata.sourceId).to eq('barcode:9191919191')
      expect(obj.identityMetadata.otherId).to match_array(@params[:other_ids].collect { |*e| e.join(':') })
      expect(obj.datastreams['descMetadata'].ng_xml).to be_equivalent_to <<-XML
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
      expect { Dor::RegistrationService.register_object(@params) }.to raise_error(Dor::ParameterError)
    end

    it "should raise an exception if the label empty and metadata_source is label or none" do
      @params[:label]=''
      @params[:metadata_source]='label'
      allow(Dor::SearchService).to receive(:query_by_id).and_return([nil])
      expect { Dor::RegistrationService.register_object(@params) }.to raise_error(Dor::ParameterError)
    end
    it "should not raise an exception if the label is empty and metadata_source is mdtoolkit" do
      @params[:label]=''
      @params[:metadata_source]='mdtoolkit'
      allow(Dor::SearchService).to receive(:query_by_id).and_return([nil])
      allow(Dor::logger).to receive(:warn)
      Dor::RegistrationService.register_object(@params)
    end

    it "should raise an exception if registering a duplicate PID" do
      @params[:pid] = @pid
      expect(Dor::SearchService).to receive(:query_by_id).with('druid:ab123cd4567').and_return([@pid])
      expect { Dor::RegistrationService.register_object(@params) }.to raise_error(Dor::DuplicateIdError)
    end

    it "should raise an exception if the label is longer than 255 chars" do
      allow(Dor::SearchService).to receive(:query_by_id).and_return([])
      @params[:label]='a'*256
      obj= Dor::RegistrationService.register_object(@params)
      expect(obj.label).to eq('a'*254)
    end
    it "should raise an exception if registering a duplicate source ID" do
      expect(Dor::SearchService).to receive(:query_by_id).with('barcode:9191919191').and_return([@pid])
      expect { Dor::RegistrationService.register_object(@params) }.to raise_error(Dor::DuplicateIdError)
    end
    it 'should set the workflow priority if one was passed in' do
      expect_any_instance_of(Dor::Item).to receive(:initialize_workflow).with('digitizationWF','dor',false,50)
      allow(Dor::SearchService).to receive(:query_by_id).and_return([nil])
      @params[:workflow_priority] = 50
      @params[:initiate_workflow] = 'digitizationWF'
      Dor::RegistrationService.register_object(@params)
    end
  end
end
