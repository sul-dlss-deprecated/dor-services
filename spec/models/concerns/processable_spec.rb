# frozen_string_literal: true

require 'spec_helper'

class ProcessableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
  include Dor::Versionable
  include Dor::Describable
end

class ProcessableOnlyItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
end

class ProcessableWithApoItem < ActiveFedora::Base
  include Dor::Governable
  include Dor::Processable
  include Dor::Itemizable
end

RSpec.describe Dor::Processable do
  after { unstub_config }

  let(:item) { instantiate_fixture('druid:ab123cd4567', ProcessableItem) }

  before do
    stub_config
    item.contentMetadata.content = '<contentMetadata/>'
  end

  it 'has a workflows datastream and workflows shortcut method' do
    expect(item.datastreams['workflows']).to be_a(Dor::WorkflowDs)
    expect(item.workflows).to eq(item.datastreams['workflows'])
  end

  it 'loads its content directly from the workflow service' do
    expect(Dor::Config.workflow.client).to receive(:get_workflow_xml).with('dor', 'druid:ab123cd4567', nil).once.and_return('<workflows/>')
    expect(item.workflows.content).to eq('<workflows/>')
  end

  it 'is able to invalidate the cache of its content' do
    expect(Dor::Config.workflow.client).to receive(:get_workflow_xml).with('dor', 'druid:ab123cd4567', nil).once.and_return('<workflows/>')
    expect(item.workflows.content).to eq('<workflows/>')
    expect(item.workflows.content).to eq('<workflows/>') # should be cached copy
    expect(Dor::Config.workflow.client).to receive(:get_workflow_xml).with('dor', 'druid:ab123cd4567', nil).once.and_return('<workflows>with some data</workflows>')
    # pass refresh flag and should be refreshed copy
    expect(item.workflows.content(true)).to eq('<workflows>with some data</workflows>')
    expect(item.workflows.content).to eq('<workflows>with some data</workflows>')
  end

  describe '#build_datastream' do
    let(:builder) { instance_double(Dor::DatastreamBuilder, build: true) }

    it 'Calls the datastream builder' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::DatastreamBuilder).to receive(:new)
        .with(datastream: Dor::DescMetadataDS, force: true, object: item, required: false)
        .and_return(builder)
      item.build_datastream('descMetadata', true)
      expect(builder).to have_received(:build)
    end
  end

  describe '#status' do
    it 'delegates to the StatusService' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::StatusService).to receive(:status).with(item, true)
      item.status(true)
    end
  end

  describe '#create_workflow' do
    let(:item) { instantiate_fixture('druid:ab123cd4567', ProcessableWithApoItem) }

    it 'delegates to CreateWorkflowService' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::CreateWorkflowService).to receive(:create_workflow).with(item, name: 'accessionWF', create_ds: true, priority: 0)
      item.create_workflow('accessionWF')
    end
  end
end
