# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::VersionService do
  class VersionableItem < ActiveFedora::Base
    include Dor::Versionable
    include Dor::Eventable
  end

  let(:druid) { 'ab12cd3456' }

  let(:obj) do
    VersionableItem.new
  end

  let(:vmd_ds) { obj.datastreams['versionMetadata'] }
  let(:ev_ds) { obj.datastreams['events'] }

  before do
    allow(obj).to receive(:pid).and_return(druid)

    allow(obj.inner_object).to receive(:repository).and_return(double('frepo').as_null_object)
  end

  describe '.open' do
    subject(:open) { described_class.open(obj) }

    context 'normal behavior' do
      before do
        allow(Dor::Config.workflow.client).to receive(:get_lifecycle).with('dor', druid, 'accessioned').and_return(true)
        allow(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', druid, 'opened').and_return(nil)
        allow(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', druid, 'submitted').and_return(nil)
        allow(Sdr::Client).to receive(:current_version).and_return(1)
        allow(Dor::CreateWorkflowService).to receive(:create_workflow).with(obj, name: 'versioningWF')
        allow(obj).to receive(:new_record?).and_return(false)
        allow(vmd_ds).to receive(:save)
      end

      it 'creates the versionMetadata datastream and starts a workflow' do
        expect(Dor::Config.workflow.client).to receive(:get_lifecycle).with('dor', druid, 'accessioned').and_return(true)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', druid, 'opened').and_return(nil)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', druid, 'submitted').and_return(nil)
        expect(Sdr::Client).to receive(:current_version).and_return(1)
        expect(Dor::CreateWorkflowService).to receive(:create_workflow).with(obj, name: 'versioningWF')
        expect(obj).to receive(:new_record?).and_return(false)
        expect(vmd_ds).to receive(:save)
        expect(vmd_ds.ng_xml.to_xml).to match(/Initial Version/)
        open
      end

      it 'includes vers_md_upd_info' do
        vers_md_upd_info = { significance: 'real_major', description: 'same as it ever was', opening_user_name: 'sunetid' }
        cur_vers = '2'
        allow(vmd_ds).to receive(:current_version).and_return(cur_vers)
        allow(obj).to receive(:save)

        expect(ev_ds).to receive(:add_event).with('open', vers_md_upd_info[:opening_user_name], "Version #{cur_vers} opened")
        expect(vmd_ds).to receive(:update_current_version).with(description: vers_md_upd_info[:description], significance: vers_md_upd_info[:significance].to_sym)
        expect(obj).to receive(:save)

        described_class.open(obj, vers_md_upd_info: vers_md_upd_info)
      end

      it "doesn't include vers_md_upd_info" do
        expect(ev_ds).not_to receive(:add_event)
        expect(vmd_ds).not_to receive(:update_current_version)
        expect(obj).not_to receive(:save)

        open
      end
    end

    context 'when the object has not been accessioned' do
      it 'raises an exception' do
        expect(Dor::Config.workflow.client).to receive(:get_lifecycle).with('dor', druid, 'accessioned').and_return(false)
        expect { open }.to raise_error(Dor::Exception, 'Object net yet accessioned')
      end
    end

    context 'when the object has already been opened' do
      it 'raises an exception' do
        expect(Dor::Config.workflow.client).to receive(:get_lifecycle).with('dor', druid, 'accessioned').and_return(true)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', druid, 'opened').and_return(Time.new)
        expect { open }.to raise_error(Dor::Exception, 'Object already opened for versioning')
      end
    end

    context 'when the object is still being accessioned' do
      it 'raises an exception' do
        expect(Dor::Config.workflow.client).to receive(:get_lifecycle).with('dor', druid, 'accessioned').and_return(true)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', druid, 'opened').and_return(nil)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', druid, 'submitted').and_return(Time.new)
        expect { open }.to raise_error(Dor::Exception, 'Object currently being accessioned')
      end
    end

    context "SDR's current version is greater than the current version" do
      it 'raises an exception' do
        expect(Dor::Config.workflow.client).to receive(:get_lifecycle).with('dor', druid, 'accessioned').and_return(true)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', druid, 'opened').and_return(nil)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', druid, 'submitted').and_return(nil)
        expect(Sdr::Client).to receive(:current_version).and_return(3)
        expect { open }.to raise_error(Dor::Exception, 'Cannot sync to a version greater than current: 1, requested 3')
      end
    end
  end

  describe '.close' do
    subject(:close) { described_class.close(obj) }

    it 'sets tag and description if passed in as optional paramaters' do
      allow(vmd_ds).to receive(:pid).and_return('druid:ab123cd4567')
      allow(Dor::Config.workflow.client).to receive(:get_active_lifecycle).and_return(true, false)

      # Stub out calls to update and archive workflow
      allow(Dor::Config.workflow.client).to receive(:update_workflow_status)

      expect(Dor::Config.workflow.client).to receive(:close_version).with('dor', druid, true)

      allow(obj).to receive(:create_workflow)

      vmd_ds.increment_version
      expect(vmd_ds).to receive(:save)
      described_class.close obj, description: 'closing text', significance: :major

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

    context 'when the object has not been opened for versioning' do
      it 'raises an exception' do
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', druid, 'opened').and_return(nil)
        expect { close }.to raise_error(Dor::Exception, 'Trying to close version on an object not opened for versioning')
      end
    end

    context 'when the object already has an active instance of accesssionWF' do
      it 'raises an exception' do
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', druid, 'opened').and_return(Time.new)
        expect(Dor::Config.workflow.client).to receive(:get_active_lifecycle).with('dor', druid, 'submitted').and_return(true)
        expect { close }.to raise_error(Dor::Exception, 'accessionWF already created for versioned object')
      end
    end

    context 'when the latest version does not have a tag and a description' do
      it 'raises an exception' do
        vmd_ds.increment_version
        expect { close }.to raise_error(Dor::Exception, 'latest version in versionMetadata requires tag and description before it can be closed')
      end
    end
  end
end
