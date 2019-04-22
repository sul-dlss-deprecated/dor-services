# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::CreateWorkflowService do
  describe '.create_workflow' do
    subject(:create_workflow) { described_class.create_workflow(item, name: 'accessionWF') }

    before do
      allow(item).to receive(:admin_policy_object).and_return(apo)
      allow(Dor::Config.workflow.client).to receive(:all_workflows_xml).with('druid:ab123cd4567').and_return('<workflows/>')
    end

    let(:apo) { instantiate_fixture('druid:fg890hi1234', Dor::AdminPolicyObject) }
    let(:item) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }

    it "sets the lane_id option from the object's APO" do
      expect(Dor::WorkflowObject).to receive(:initial_workflow).and_return('<xml/>')
      expect(Dor::WorkflowObject).to receive(:initial_repo).and_return('dor')
      expect(Dor::Config.workflow.client).to receive(:create_workflow).with('dor', 'druid:ab123cd4567', 'accessionWF', '<xml/>', create_ds: true, lane_id: 'fast')

      create_workflow
    end
  end

  describe '#default_workflow_lane' do
    subject { described_class.new(item).send(:default_workflow_lane) }

    let(:item) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }

    context 'when the object has an APO' do
      before do
        allow(item).to receive(:admin_policy_object).and_return(apo)
      end

      context 'with the fast lane defined in the apo' do
        let(:apo) { instantiate_fixture('druid:fg890hi1234', Dor::AdminPolicyObject) }

        it { is_expected.to eq 'fast' }
      end

      context 'without a lane defined' do
        let(:apo) { instantiate_fixture('druid:zt570tx3016', Dor::AdminPolicyObject) }

        it { is_expected.to eq 'default' }
      end

      context 'without administrativeMetadata' do
        let(:apo) { instantiate_fixture('druid:fg890hi1234', Dor::AdminPolicyObject) }

        before do
          allow(apo.datastreams).to receive(:[]).with('administrativeMetadata').and_return(nil)
        end

        it { is_expected.to eq 'default' }
      end
    end

    context 'when the object does not have an apo' do
      before do
        allow(item).to receive(:admin_policy_object).and_return(nil)
      end

      it { is_expected.to eq 'default' }
    end

    context 'when the object is newly created' do
      let(:item) do
        Dor::Item.new.tap do |i|
          i.admin_policy_object = instantiate_fixture('druid:zt570tx3016', Dor::AdminPolicyObject)
        end
      end

      it { is_expected.to eq 'default' }
    end
  end
end
