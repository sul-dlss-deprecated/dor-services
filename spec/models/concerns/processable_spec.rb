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
end

RSpec.describe Dor::Processable do
  after(:each) { unstub_config }

  before do
    stub_config
    @item = instantiate_fixture('druid:ab123cd4567', ProcessableItem)
    @item.contentMetadata.content = '<contentMetadata/>'
  end

  it 'has a workflows datastream and workflows shortcut method' do
    expect(@item.datastreams['workflows']).to be_a(Dor::WorkflowDs)
    expect(@item.workflows).to eq(@item.datastreams['workflows'])
  end

  it 'should load its content directly from the workflow service' do
    expect(Dor::Config.workflow.client).to receive(:get_workflow_xml).with('dor', 'druid:ab123cd4567', nil).once { '<workflows/>' }
    expect(@item.workflows.content).to eq('<workflows/>')
  end

  it 'should be able to invalidate the cache of its content' do
    expect(Dor::Config.workflow.client).to receive(:get_workflow_xml).with('dor', 'druid:ab123cd4567', nil).once { '<workflows/>' }
    expect(@item.workflows.content).to eq('<workflows/>')
    expect(@item.workflows.content).to eq('<workflows/>') # should be cached copy
    expect(Dor::Config.workflow.client).to receive(:get_workflow_xml).with('dor', 'druid:ab123cd4567', nil).once { '<workflows>with some data</workflows>' }
    # pass refresh flag and should be refreshed copy
    expect(@item.workflows.content(true)).to eq('<workflows>with some data</workflows>')
    expect(@item.workflows.content).to eq('<workflows>with some data</workflows>')
  end

  describe '#build_datastream' do
    let(:builder) { instance_double(Dor::DatastreamBuilder, build: true) }

    it 'Calls the datastream builder' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::DatastreamBuilder).to receive(:new)
        .with(datastream: Dor::DescMetadataDS, force: true, object: @item, required: false)
        .and_return(builder)
      @item.build_datastream('descMetadata', true)
      expect(builder).to have_received(:build)
    end
  end

  describe 'status gv054hp4128' do
    before :all do
      xml = '<?xml version="1.0" encoding="UTF-8"?>
      <lifecycle objectId="druid:gv054hp4128">
      <milestone date="2012-11-06T16:19:15-0800" version="2">described</milestone>
      <milestone date="2012-11-06T16:59:39-0800" version="3">published</milestone>
      </lifecycle>
      '
      @gv054hp4128 = Nokogiri::XML(xml)
    end
    before :each do
      allow_any_instance_of(Dor::Workflow::Document).to receive(:to_solr).and_return(nil)
      @versionMD = double(Dor::VersionMetadataDS)
      expect(@item).to receive(:versionMetadata).and_return(@versionMD)
    end
    it 'should generate a status string' do
      xml = '<?xml version="1.0" encoding="UTF-8"?>
      <lifecycle objectId="druid:gv054hp4128">
      <milestone date="2012-11-06T16:19:15-0800" version="2">described</milestone>
      <milestone date="2012-11-06T16:21:02-0800">opened</milestone>
      <milestone date="2012-11-06T16:30:03-0800">submitted</milestone>
      <milestone date="2012-11-06T16:35:00-0800">described</milestone>
      <milestone date="2012-11-06T16:59:39-0800" version="3">published</milestone>
      <milestone date="2012-11-06T16:59:39-0800">published</milestone>
      </lifecycle>
      '
      xml = Nokogiri::XML(xml)
      expect(Dor::Config.workflow.client).to receive(:query_lifecycle).and_return(xml)
      expect(@versionMD).to receive(:current_version_id).and_return('4')
      expect(@item.status).to eq('v4 In accessioning (described, published)')
    end
    it 'should generate a status string' do
      expect(Dor::Config.workflow.client).to receive(:query_lifecycle).and_return(@gv054hp4128)
      expect(@versionMD).to receive(:current_version_id).and_return('3')
      expect(@item.status).to eq('v3 In accessioning (described, published)')
    end
    it 'should generate a status string' do
      expect(Dor::Config.workflow.client).to receive(:query_lifecycle).and_return(@gv054hp4128)
      expect(@versionMD).to receive(:current_version_id).and_return('3')
      expect(@item.status).to eq('v3 In accessioning (described, published)')
    end
  end

  describe 'status bd504dj1946' do
    before :all do
      @miles = '<?xml version="1.0"?>
      <lifecycle objectId="druid:bd504dj1946">
      <milestone date="2013-04-03T15:01:57-0700">registered</milestone>
      <milestone date="2013-04-03T16:20:19-0700">digitized</milestone>
      <milestone date="2013-04-16T14:18:20-0700" version="1">submitted</milestone>
      <milestone date="2013-04-16T14:32:54-0700" version="1">described</milestone>
      <milestone date="2013-04-16T14:55:10-0700" version="1">published</milestone>
      <milestone date="2013-07-21T05:27:23-0700" version="1">deposited</milestone>
      <milestone date="2013-07-21T05:28:09-0700" version="1">accessioned</milestone>
      <milestone date="2013-08-15T11:59:16-0700" version="2">opened</milestone>
      <milestone date="2013-10-01T12:01:07-0700" version="2">submitted</milestone>
      <milestone date="2013-10-01T12:01:24-0700" version="2">described</milestone>
      <milestone date="2013-10-01T12:05:38-0700" version="2">published</milestone>
      <milestone date="2013-10-01T12:10:56-0700" version="2">deposited</milestone>
      <milestone date="2013-10-01T12:11:10-0700" version="2">accessioned</milestone>
      </lifecycle>'
      @xml = Nokogiri::XML(@miles)
    end
    before :each do
      @versionMD = double(Dor::VersionMetadataDS)
      allow_any_instance_of(Dor::Workflow::Document).to receive(:to_solr).and_return(nil)
      expect(@item).to receive(:versionMetadata).and_return(@versionMD)
      expect(Dor::Config.workflow.client).to receive(:query_lifecycle).and_return(@xml)
    end

    it 'should handle a v2 accessioned object' do
      expect(@versionMD).to receive(:current_version_id).and_return('2')
      expect(@item.status).to eq('v2 Accessioned')
    end
    it 'should give a status of unknown if there are no lifecycles for the current version, indicating malfunction in workflow' do
      expect(@versionMD).to receive(:current_version_id).and_return('3')
      expect(@item.status).to eq('v3 Unknown Status')
    end
    it 'should include a formatted date/time if one is requested' do
      expect(@versionMD).to receive(:current_version_id).and_return('2')
      expect(@item.status(true)).to eq('v2 Accessioned 2013-10-01 07:11PM')
    end
  end

  describe '#create_workflow' do
    it "sets the lane_id option from the object's APO" do
      apo  = instantiate_fixture('druid:fg890hi1234', Dor::AdminPolicyObject)
      item = instantiate_fixture('druid:ab123cd4567', ProcessableWithApoItem)
      allow(item).to receive(:admin_policy_object) { apo }
      expect(Dor::WorkflowObject).to receive(:initial_workflow).and_return('<xml/>')
      expect(Dor::WorkflowObject).to receive(:initial_repo).and_return('dor')
      expect(Dor::Config.workflow.client).to receive(:create_workflow).with('dor', 'druid:ab123cd4567', 'accessionWF', '<xml/>', create_ds: true, lane_id: 'fast')
      item.create_workflow('accessionWF')
    end
  end
end
