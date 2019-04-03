# frozen_string_literal: true

require 'spec_helper'

class VersionableItem < ActiveFedora::Base
  include Dor::Versionable
  include Dor::Eventable
end

RSpec.describe Dor::Versionable do
  let(:dr) { 'ab12cd3456' }

  let(:obj) do
    v = VersionableItem.new
    allow(v).to receive(:pid).and_return(dr)
    v
  end

  let(:vmd_ds) { obj.datastreams['versionMetadata'] }
  let(:ev_ds) { obj.datastreams['events'] }

  before do
    allow(obj.inner_object).to receive(:repository).and_return(double('frepo').as_null_object)
  end

  describe '#open_new_version' do
    it 'delegates to version service' do
      expect(Dor::VersionService).to receive(:open).with(obj, {})
      expect(Deprecation).to receive(:warn)
      obj.open_new_version
    end
  end

  describe '#close_version' do
    it 'delegates to version service' do
      expect(Dor::VersionService).to receive(:close).with(obj, {})
      expect(Deprecation).to receive(:warn)
      obj.close_version
    end
  end

  describe 'allows_modification?' do
    it "allows modification if the object hasn't been submitted" do
      allow(Dor::Config.workflow.client).to receive(:lifecycle).and_return(false)
      expect(obj).to be_allows_modification
    end

    it 'allows modification if there is an open version' do
      allow(Dor::Config.workflow.client).to receive(:lifecycle).and_return(true)
      allow_any_instance_of(Dor::VersionService).to receive(:open?).and_return(true)
      expect(obj).to be_allows_modification
    end

    it 'allows modification if the item has sdr-ingest-transfer set to hold' do
      allow(Dor::Config.workflow.client).to receive(:lifecycle).and_return(true)
      allow_any_instance_of(Dor::VersionService).to receive(:open?).and_return(false)
      allow(Dor::Config.workflow.client).to receive(:workflow_status).and_return('hold')
      expect(obj).to be_allows_modification
    end
  end
end
