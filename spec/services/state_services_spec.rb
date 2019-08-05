# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::StateService do
  let(:service) { described_class.new(pid) }

  describe '#allows_modification?' do
    let(:pid) { 'ab12cd3456' }

    it "allows modification if the object hasn't been submitted" do
      allow(Dor::Config.workflow.client).to receive(:lifecycle).and_return(false)
      expect(service).to be_allows_modification
    end

    it 'allows modification if there is an open version' do
      allow(Dor::Config.workflow.client).to receive(:lifecycle).and_return(true)
      allow(Dor::Config.workflow.client).to receive(:active_lifecycle).and_return(true)
      expect(service).to be_allows_modification
    end

    it 'allows modification if the item has sdr-ingest-transfer set to hold' do
      allow(Dor::Config.workflow.client).to receive(:lifecycle).and_return(true)
      allow(Dor::Config.workflow.client).to receive(:active_lifecycle).and_return(false)
      allow(Dor::Config.workflow.client).to receive(:workflow_status).and_return('hold')
      expect(service).to be_allows_modification
    end
  end
end
