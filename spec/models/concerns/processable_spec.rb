# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Processable do
  after { unstub_config }

  let(:item) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }

  before do
    stub_config
    item.contentMetadata.content = '<contentMetadata/>'
  end

  it 'has a workflows datastream and workflows shortcut method' do
    expect(item.datastreams['workflows']).to be_a(Dor::WorkflowDs)
    expect(item.workflows).to eq(item.datastreams['workflows'])
  end

  it 'loads its content directly from the workflow service' do
    expect(Dor::Config.workflow.client).to receive(:all_workflows_xml).with('druid:ab123cd4567').and_return('<workflows/>')
    expect(item.workflows.content).to eq('<workflows/>')
  end

  it 'is able to invalidate the cache of its content' do
    expect(Dor::Config.workflow.client).to receive(:all_workflows_xml).with('druid:ab123cd4567').and_return('<workflows/>')
    expect(item.workflows.content).to eq('<workflows/>')
    expect(item.workflows.content).to eq('<workflows/>') # should be cached copy
    expect(Dor::Config.workflow.client).to receive(:all_workflows_xml).with('druid:ab123cd4567').and_return('<workflows>with some data</workflows>')
    # pass refresh flag and should be refreshed copy
    expect(item.workflows.content(true)).to eq('<workflows>with some data</workflows>')
    expect(item.workflows.content).to eq('<workflows>with some data</workflows>')
  end
end
