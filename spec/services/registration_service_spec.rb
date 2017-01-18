require 'spec_helper'

describe Dor::RegistrationService do
  before(:each) { stub_config }
  after(:each)  { unstub_config }

  before :each do
    @pid = 'druid:ab123cd4567'
    @mock_repo = double(Rubydora::Repository, :url => 'foo')
    @mock_solr = double(RSolr::Connection).as_null_object
    @apo = instantiate_fixture('druid:fg890hi1234', Dor::AdminPolicyObject)
    allow(@apo).to receive(:new_record?).and_return false
    allow(Dor).to receive(:find).with('druid:fg890hi1234').and_return(@apo)
  end

  context '#register_object' do
    before :each do
      allow(Dor::SuriService).to receive(:mint_id).and_return(@pid)
      allow(Dor::SearchService).to receive(:query_by_id).and_return([])
      allow(ActiveFedora::Base).to receive(:connection_for_pid).and_return(@mock_repo)
      allow(Dor::SearchService).to receive(:solr).and_return(@mock_solr)
      # allow_any_instance_of(Dor::Item).to receive(:save).and_return(true)
      allow_any_instance_of(Dor::Collection).to receive(:save).and_return(true)
      allow_any_instance_of(Dor::Item).to receive(:create).and_return(true)

      @params = {
        :object_type   => 'item',
        :content_model => 'googleScannedBook',
        :admin_policy  => 'druid:fg890hi1234',
        :label         => 'Google : Scanned Book 12345',
        :source_id     => { :barcode => 9191919191 },
        :other_ids     => { :catkey => '000', :uuid => '111' },
        :tags          => ['Google : Google Tag!', 'Google : Other Google Tag!']
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
    let(:world_xml) {
      <<-XML
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
    }
    let(:stanford_xml) {
      <<-XML
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
              <group>stanford</group>
            </machine>
          </access>
          <use>
            <human type="creativecommons">Attribution Share Alike license</human>
            <machine type="creativecommons">by-sa</machine>
          </use>
        </rightsMetadata>
      XML
    }
    let(:stanford_no_download_xml) {
      <<-XML
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
              <group rule="no-download">stanford</group>
            </machine>
          </access>
          <use>
            <human type="creativecommons">Attribution Share Alike license</human>
            <machine type="creativecommons">by-sa</machine>
          </use>
        </rightsMetadata>
      XML
    }
    let(:location_music_xml) {
      <<-XML
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
              <location>music</location>
            </machine>
          </access>
          <use>
            <human type="creativecommons">Attribution Share Alike license</human>
            <machine type="creativecommons">by-sa</machine>
          </use>
        </rightsMetadata>
      XML
    }

    context 'exception should be raised for' do
      it 'registering a duplicate PID' do
        @params[:pid] = @pid
        expect(Dor::SearchService).to receive(:query_by_id).with('druid:ab123cd4567').and_return([@pid])
        expect { Dor::RegistrationService.register_object(@params) }.to raise_error(Dor::DuplicateIdError)
      end
      it 'registering a duplicate source ID' do
        expect(Dor::SearchService).to receive(:query_by_id).with('barcode:9191919191').and_return([@pid])
        expect { Dor::RegistrationService.register_object(@params) }.to raise_error(Dor::DuplicateIdError)
      end
      it 'missing a required parameter' do
        @params.delete(:object_type)
        expect { Dor::RegistrationService.register_object(@params) }.to raise_error(Dor::ParameterError)
      end
      context 'empty label' do
        before :each do
          @params[:label] = ''
        end
        it 'and metadata_source is label or none' do
          @params[:metadata_source] = 'label'
          expect { Dor::RegistrationService.register_object(@params) }.to raise_error(Dor::ParameterError)
          @params[:metadata_source] = 'none'
          expect { Dor::RegistrationService.register_object(@params) }.to raise_error(Dor::ParameterError)
        end
      end
    end

    RSpec.shared_examples 'common registration' do
      it 'produces a registered object' do
        expect(@obj.pid).to eq(@pid)
        expect(@obj.label).to eq(@params[:label])
        expect(@obj.identityMetadata.sourceId).to eq('barcode:9191919191')
        expect(@obj.identityMetadata.otherId).to match_array(@params[:other_ids].collect { |*e| e.join(':') })
      end
    end

    describe 'should set rightsMetadata based on the APO default (but replace read rights) even if it is a collection' do
      before :each do
        @coll = Dor::Collection.new(:pid => @pid)
        expect(Dor::Collection).to receive(:new).with(:pid => @pid).and_return(@coll)
        @params[:rights] = 'stanford'
        @params[:object_type] = 'collection'
        @obj = Dor::RegistrationService.register_object(@params)
      end
      it_behaves_like 'common registration'
      it 'produces rightsMetadata XML' do
        expect(@obj.datastreams['rightsMetadata'].ng_xml).to be_equivalent_to stanford_xml
      end
    end

    context 'common cases' do
      before :each do
        expect_any_instance_of(Dor::Item).to receive(:save).and_return(true)
      end

      describe 'object registration' do
        before :each do
          @obj = Dor::RegistrationService.register_object(@params)
        end
        it_behaves_like 'common registration'
        it 'produces correct rels_ext' do
          expect(@obj.rels_ext.to_rels_ext).to be_equivalent_to <<-XML
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#"
              xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#">
              <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
                <hydra:isGovernedBy rdf:resource="info:fedora/druid:fg890hi1234"/>
                <fedora-model:hasModel rdf:resource="info:fedora/afmodel:Dor_Item"/>
                <fedora-model:hasModel rdf:resource='info:fedora/afmodel:Dor_Abstract' />
                <fedora:isMemberOf rdf:resource="info:fedora/druid:zb871zd0767"/>
                <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:zb871zd0767"/>
              </rdf:Description>
            </rdf:RDF>
          XML
        end
      end

      describe 'collection registration' do
        before :each do
          @params[:collection] = 'druid:something'
          expect(Dor::Collection).to receive(:find).with('druid:something').and_return(mock_collection)
          @obj = Dor::RegistrationService.register_object(@params)
        end
        it_behaves_like 'common registration'
        it 'produces correct RELS-EXT' do
          expect(@obj.datastreams['RELS-EXT'].to_rels_ext).to be_equivalent_to <<-XML
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#"
              xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#">
              <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
                <hydra:isGovernedBy rdf:resource="info:fedora/druid:fg890hi1234"/>
                <fedora-model:hasModel rdf:resource="info:fedora/afmodel:Dor_Item"/>
                <fedora-model:hasModel rdf:resource='info:fedora/afmodel:Dor_Abstract' />
                <fedora:isMemberOf rdf:resource="info:fedora/druid:something"/>
                <fedora:isMemberOf rdf:resource="info:fedora/druid:zb871zd0767"/>
                <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:something"/>
                <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:zb871zd0767"/>
              </rdf:Description>
            </rdf:RDF>
          XML
        end
      end

      context 'when passed rights=' do
        describe 'default' do
          before :each do
            @params[:rights] = 'default'
            @obj = Dor::RegistrationService.register_object(@params)
          end
          it_behaves_like 'common registration'
          it 'sets rightsMetadata based on the APO default' do
            expect(@obj.datastreams['rightsMetadata'].ng_xml).to be_equivalent_to stanford_xml
          end
        end
        describe 'world' do
          before :each do
            @params[:rights] = 'world'
            @obj = Dor::RegistrationService.register_object(@params)
          end
          it_behaves_like 'common registration'
          it 'sets rightsMetadata based on the APO default but replace read rights to be world' do
            expect(@obj.datastreams['rightsMetadata'].ng_xml).to be_equivalent_to world_xml
          end
        end
        describe 'loc:music' do
          before :each do
            @params[:rights] = 'loc:music'
            @obj = Dor::RegistrationService.register_object(@params)
          end
          it_behaves_like 'common registration'
          it 'sets rightsMetadata based on the APO default but replace read rights to be loc:music' do
            expect(@obj.datastreams['rightsMetadata'].ng_xml).to be_equivalent_to location_music_xml
          end
        end
        describe 'stanford no-download' do
          before :each do
            @params[:rights] = 'stanford-nd'
            @obj = Dor::RegistrationService.register_object(@params)
          end
          it_behaves_like 'common registration'
          it 'sets rightsMetadata based on the APO default but replace read rights to be group stanford with the no-download rule' do
            expect(@obj.datastreams['rightsMetadata'].ng_xml).to be_equivalent_to stanford_no_download_xml
          end
        end
      end

      describe 'when passed metadata_source=label' do
        before :each do
          @params[:metadata_source] = 'label'
          @obj = Dor::RegistrationService.register_object(@params)
        end
        it_behaves_like 'common registration'
        it 'should set the descriptive metadata to basic mods using the label as title' do
          expect(@obj.datastreams['descMetadata'].ng_xml).to be_equivalent_to <<-XML
            <?xml version="1.0"?>
            <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
               <titleInfo>
                  <title>Google : Scanned Book 12345</title>
               </titleInfo>
            </mods>
          XML
        end
      end

      it 'truncates label if >= 255 chars' do
        # expect(Dor.logger).to receive(:warn).at_least(:once)
        @params[:label] = 'a' * 256
        obj = Dor::RegistrationService.register_object(@params)
        expect(obj.label).to eq('a' * 254)
      end

      it 'sets workflow priority when passed in' do
        expect_any_instance_of(Dor::Item).to receive(:create_workflow).with('digitizationWF', false, 50)
        @params[:workflow_priority] = 50
        @params[:initiate_workflow] = 'digitizationWF'
        Dor::RegistrationService.register_object(@params)
      end
    end # context common cases

  end

  context '#create_from_request' do
    before :each do
      allow(Dor::SuriService).to receive(:mint_id).and_return(@pid)
      allow(Dor::SearchService).to receive(:query_by_id).and_return([])
      allow(ActiveFedora::Base).to receive(:connection_for_pid).and_return(@mock_repo)
      # allow(Dor::SearchService).to receive(:solr).and_return(@mock_solr)
      allow_any_instance_of(Dor::Item).to receive(:save).and_return(true)
      # allow_any_instance_of(Dor::Collection).to receive(:save).and_return(true)
      allow_any_instance_of(Dor::Item).to receive(:create).and_return(true)

      @params = {
        :object_type   => 'item',
        :admin_policy  => 'druid:fg890hi1234',
        :label         => 'web-archived-crawl for http://www.example.org',
        :source_id     => 'sul:SOMETHING-www.example.org'
      }
    end

    context 'exception should be raised for' do
      it 'a source ID not having exactly one colon' do
        expect { Dor::RegistrationService.create_from_request(@params) }.not_to raise_error
        # Generic error is raised in #ids_to_hash before code gets to specific Source ID error message
        @params[:source_id] = 'sul:SOMETHING-http://www.example.org'
        exp_regex = /invalid number of elements/
        expect { Dor::RegistrationService.create_from_request(@params) }.to raise_error(ArgumentError, exp_regex)
        # Execution gets into IdentityMetadataDS code for specific error
        @params[:source_id] = 'no-colon'
        exp_regex = /Source ID must follow the format 'namespace:value'/
        expect { Dor::RegistrationService.create_from_request(@params) }.to raise_error(ArgumentError, exp_regex)
      end
      it 'other_id with more than one colon' do
        @params[:other_id] = 'no-colon'
        expect { Dor::RegistrationService.create_from_request(@params) }.not_to raise_error
        @params[:other_id] = 'catkey:000'
        expect { Dor::RegistrationService.create_from_request(@params) }.not_to raise_error
        # Generic error is raised in #ids_to_hash
        @params[:other_id] = 'catkey:oop:sie'
        exp_regex = /invalid number of elements/
        expect { Dor::RegistrationService.create_from_request(@params) }.to raise_error(ArgumentError, exp_regex)
      end
    end
  end
end
