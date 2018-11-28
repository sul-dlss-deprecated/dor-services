# frozen_string_literal: true

require 'spec_helper'

class VersionableItem < ActiveFedora::Base
  include Dor::Versionable
  include Dor::Eventable
end

describe Dor::Versionable do
  let(:dr) { 'ab12cd3456' }

  let(:obj) {
    v = VersionableItem.new
    allow(v).to receive(:pid).and_return(dr)
    v
  }

  let(:vmd_ds) { obj.datastreams['versionMetadata'] }
  let(:ev_ds) { obj.datastreams['events'] }

  before(:each) do
    allow(obj.inner_object).to receive(:repository).and_return(double('frepo').as_null_object)
  end

  describe '#open_new_version' do
    context 'normal behavior' do
      before(:each) do
        expect(Dor::Config.workflow.client).to receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(true)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(nil)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', dr, 'submitted').and_return(nil)
        expect(Sdr::Client).to receive(:current_version).and_return(1)
        expect(obj).to receive(:create_workflow).with('versioningWF')
        expect(obj).to receive(:new_record?).and_return(false)
        expect(vmd_ds).to receive(:save)
      end

      it 'checks if an object has been accessioned and not yet opened' do
        # checked in before block
        obj.open_new_version
      end

      it 'creates the versionMetadata datastream' do
        expect(vmd_ds.ng_xml.to_xml).to match(/Initial Version/)
        obj.open_new_version
      end

      it 'adds versioningWF' do
        # checked in before block
        obj.open_new_version
      end

      it 'sets the content with the new ng_xml' do
        obj.open_new_version
      end

      it 'saves the datastream' do
        obj.open_new_version
      end

      it 'includes vers_md_upd_info' do
        vers_md_upd_info = { :significance => 'real_major', :description => 'same as it ever was', :opening_user_name => 'sunetid' }
        cur_vers = '2'
        allow(vmd_ds).to receive(:current_version).and_return(cur_vers)
        allow(obj).to receive(:save)

        expect(ev_ds).to receive(:add_event).with('open', vers_md_upd_info[:opening_user_name], "Version #{cur_vers} opened")
        expect(vmd_ds).to receive(:update_current_version).with({ :description => vers_md_upd_info[:description], :significance => vers_md_upd_info[:significance].to_sym })
        expect(obj).to receive(:save)

        obj.open_new_version({ :vers_md_upd_info => vers_md_upd_info })
      end

      it "doesn't include vers_md_upd_info" do
        expect(ev_ds).not_to receive(:add_event)
        expect(vmd_ds).not_to receive(:update_current_version)
        expect(obj).not_to receive(:save)

        obj.open_new_version
      end
    end

    context 'error handling' do
      it 'raises an exception if it the object has not yet been accessioned' do
        expect(Dor::Config.workflow.client).to receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(false)
        expect { obj.open_new_version }.to raise_error(Dor::Exception, 'Object net yet accessioned')
      end

      it 'raises an exception if the object has already been opened' do
        expect(Dor::Config.workflow.client).to receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(true)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(Time.new)
        expect { obj.open_new_version }.to raise_error(Dor::Exception, 'Object already opened for versioning')
      end

      it 'raises an exception if the object is still being accessioned' do
        expect(Dor::Config.workflow.client).to receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(true)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(nil)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', dr, 'submitted').and_return(Time.new)
        expect { obj.open_new_version }.to raise_error(Dor::Exception, 'Object currently being accessioned')
      end

      it "raises an exception if SDR's current version is greater than the current version" do
        expect(Dor::Config.workflow.client).to receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(true)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(nil)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', dr, 'submitted').and_return(nil)
        expect(Sdr::Client).to receive(:current_version).and_return(3)
        expect { obj.open_new_version }.to raise_error(Dor::Exception, 'Cannot sync to a version greater than current: 1, requested 3')
      end
    end
  end

  describe '#close_version' do
    it 'kicks off common-accesioning' do
      skip 'write accessioning test'
    end

    it 'sets versioningWF:submit-version and versioningWF:start-accession to completed' do
      skip 'write versioningWF:submit-version test'
    end

    it 'sets tag and description if passed in as optional paramaters' do
      allow(vmd_ds).to receive(:pid).and_return('druid:ab123cd4567')
      allow(Dor::Config.workflow.client).to receive(:get_active_lifecycle).and_return(true, false)

      # Stub out calls to update and archive workflow
      allow(Dor::Config.workflow.client).to receive(:update_workflow_status)

      expect(Dor::Config.workflow.client).to receive(:close_version).with('dor', dr, true)

      allow(obj).to receive(:create_workflow)

      vmd_ds.increment_version
      expect(vmd_ds).to receive(:save)
      obj.close_version :description => 'closing text', :significance => :major

      expect(vmd_ds.to_xml).to be_equivalent_to(<<-XML
        <versionMetadata objectId="druid:ab123cd4567">
          <version versionId="1" tag="1.0.0">
            <description>Initial Version</description>
          </version>
          <version versionId="2" tag="2.0.0">
            <description>closing text</description>
          </version>
        </versionMetadata>
      XML
                                               )
    end

    context 'error handling' do
      it 'raises an exception if the object has not been opened for versioning' do
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(nil)
        expect { obj.close_version }.to raise_error(Dor::Exception, 'Trying to close version on an object not opened for versioning')
      end

      it 'raises an exception if the object has already has an active instance of accesssionWF' do
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(Time.new)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', dr, 'submitted').and_return(true)
        expect { obj.submit_version }.to raise_error(Dor::Exception, 'accessionWF already created for versioned object')
      end

      it 'raises an exception if the latest version does not have a tag and a description' do
        vmd_ds.increment_version
        expect { obj.close_version }.to raise_error(Dor::Exception, 'latest version in versionMetadata requires tag and description before it can be closed')
      end
    end
  end
  describe 'allows_modification?' do
    it 'should allow modification if the object hasnt been submitted' do
      allow(Dor::Config.workflow.client).to receive(:get_lifecycle).and_return(false)
      expect(obj.allows_modification?).to be_truthy
    end
    it 'should allow modification if there is an open version' do
      allow(Dor::Config.workflow.client).to receive(:get_lifecycle).and_return(true)
      allow(obj).to receive(:new_version_open?).and_return(true)
      expect(obj.allows_modification?).to be_truthy
    end
    it 'should allow modification if the item has sdr-ingest-transfer set to hold' do
      allow(Dor::Config.workflow.client).to receive(:get_lifecycle).and_return(true)
      allow(obj).to receive(:new_version_open?).and_return(false)
      allow(Dor::Config.workflow.client).to receive(:get_workflow_status).and_return('hold')
      expect(obj.allows_modification?).to be_truthy
    end
  end
end
