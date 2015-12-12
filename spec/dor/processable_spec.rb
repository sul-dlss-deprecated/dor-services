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

describe Dor::Processable do

  before(:each) { stub_config   }
  after(:each)  { unstub_config }

  before :each do
    @item = instantiate_fixture('druid:ab123cd4567', ProcessableItem)
    @item.contentMetadata.content = '<contentMetadata/>'
  end

  it 'has a workflows datastream and workflows shortcut method' do
    expect(@item.datastreams['workflows']).to be_a(Dor::WorkflowDs)
    expect(@item.workflows).to eq(@item.datastreams['workflows'])
  end

  it 'should load its content directly from the workflow service' do
    expect(Dor::WorkflowService).to receive(:get_workflow_xml).with('dor', 'druid:ab123cd4567', nil).once { '<workflows/>' }
    expect(@item.workflows.content).to eq('<workflows/>')
  end

  it 'should be able to invalidate the cache of its content' do
    expect(Dor::WorkflowService).to receive(:get_workflow_xml).with('dor', 'druid:ab123cd4567', nil).once { '<workflows/>' }
    expect(@item.workflows.content).to eq('<workflows/>')
    expect(@item.workflows.content).to eq('<workflows/>') # should be cached copy
    expect(Dor::WorkflowService).to receive(:get_workflow_xml).with('dor', 'druid:ab123cd4567', nil).once { '<workflows>with some data</workflows>' }
    # pass refresh flag and should be refreshed copy
    expect(@item.workflows.content(true)).to eq('<workflows>with some data</workflows>')
  end

  context 'build_datastream()' do

    before(:each) do
      # Paths to two files with the same content.
      f1 = 'workspace/ab/123/cd/4567/ab123cd4567/metadata/descMetadata.xml'
      f2 = 'workspace/ab/123/cd/4567/desc_metadata.xml'
      @dm_filename = File.join(@fixture_dir, f1)  # Path used inside build_datastream().
      @dm_fixture_xml = read_fixture(f2)          # Path to fixture.
      @dm_builder_xml = @dm_fixture_xml.sub(/FROM_FILE/, 'FROM_BUILDER')
    end

    context 'datastream exists as a file' do

      before(:each) do
        allow(@item).to receive(:find_metadata_file).and_return(@dm_filename)
        allow(File).to receive(:read).and_return(@dm_fixture_xml)
        @t = Time.now
      end

      it 'file newer than datastream: should read content from file' do
        allow(File).to receive(:mtime).and_return(@t)
        allow(@item.descMetadata).to receive(:createDate).and_return(@t - 99)
        xml = @dm_fixture_xml
        expect(@item.descMetadata.ng_xml).not_to be_equivalent_to(xml)
        @item.build_datastream('descMetadata', true)
        expect(@item.descMetadata.ng_xml).to be_equivalent_to(xml)
        expect(@item.descMetadata.ng_xml).not_to be_equivalent_to(@dm_builder_xml)
      end

      it 'file older than datastream: should use the builder' do
        allow(File).to receive(:mtime).and_return(@t - 99)
        allow(@item.descMetadata).to receive(:createDate).and_return(@t)
        xml = @dm_builder_xml
        allow(@item).to receive(:fetch_descMetadata_datastream).and_return(xml)
        expect(@item.descMetadata.ng_xml).not_to be_equivalent_to(xml)
        @item.build_datastream('descMetadata', true)
        expect(@item.descMetadata.ng_xml).to be_equivalent_to(xml)
        expect(@item.descMetadata.ng_xml).not_to be_equivalent_to(@dm_fixture_xml)
      end

    end

    context 'datastream does not exist as a file' do

      before(:each) do
        allow(@item).to receive(:find_metadata_file).and_return(nil)
      end

      it 'should use the datastream builder' do
        xml = @dm_builder_xml
        allow(@item).to receive(:fetch_descMetadata_datastream).and_return(xml)
        expect(@item.descMetadata.ng_xml).not_to be_equivalent_to(xml)
        @item.build_datastream('descMetadata')
        expect(@item.descMetadata.ng_xml).to be_equivalent_to(xml)
        expect(@item.descMetadata.ng_xml).not_to be_equivalent_to(@dm_fixture_xml)
      end

      it 'should raise an exception if required datastream cannot be generated' do
        # Fails because there is no build_contentMetadata_datastream() method.
        expect { @item.build_datastream('contentMetadata', false, true) }.to raise_error(RuntimeError)
      end

    end

  end

  describe 'to_solr' do
    before :each do
      xml = '<?xml version="1.0" encoding="UTF-8"?>
      <lifecycle objectId="druid:gv054hp4128">
      <milestone date="2012-01-26T21:06:54-0800" version="2">published</milestone>
      <milestone date="2012-10-29T16:30:07-0700" version="2">opened</milestone>
      <milestone date="2012-11-06T16:18:24-0800" version="2">submitted</milestone>
      <milestone date="2012-11-06T16:19:07-0800" version="2">published</milestone>
      <milestone date="2012-11-06T16:19:10-0800" version="2">accessioned</milestone>
      <milestone date="2012-11-06T16:19:15-0800" version="2">described</milestone>
      <milestone date="2012-11-06T16:21:02-0800">opened</milestone>
      <milestone date="2012-11-06T16:30:03-0800">submitted</milestone>
      <milestone date="2012-11-06T16:35:00-0800">described</milestone>
      <milestone date="2012-11-06T16:59:39-0800" version="3">published</milestone>
      <milestone date="2012-11-06T16:59:39-0800">published</milestone>
      </lifecycle>'
      dsxml = '
      <versionMetadata objectId="druid:ab123cd4567">
      <version versionId="1" tag="1.0.0">
      <description>Initial version</description>
      </version>
      <version versionId="2" tag="2.0.0">
      <description>Replacing main PDF</description>
      </version>
      <version versionId="3" tag="2.1.0">
      <description>Fixed title typo</description>
      </version>
      <version versionId="4" tag="2.2.0">
      <description>Another typo</description>
      </version>
      </versionMetadata>
      '

      xml = Nokogiri::XML(xml)
      allow(Dor::WorkflowService).to receive(:query_lifecycle).and_return(xml)
      allow_any_instance_of(Dor::Workflow::Document).to receive(:to_solr).and_return(nil)
      @versionMD = Dor::VersionMetadataDS.from_xml(dsxml)
      allow(@item).to receive(:versionMetadata).and_return(@versionMD)
    end

    it 'should include the semicolon delimited version, an earliest published date and a status' do
      #     allow(@item.descMetadata).to receive(:to_solr).and_return({})
      expect(Dor.logger).to receive(:warn)
      solr_doc = @item.to_solr
      # lifecycle_display should have the semicolon delimited version
      expect(solr_doc['lifecycle_ssim']).to include('published:2012-01-27T05:06:54Z;2')
      # published date should be the first published date
      expect(solr_doc).to match a_hash_including('status_ssi' => 'v4 In accessioning (described, published)')
      expect(solr_doc).to match a_hash_including('opened_dttsim' => including('2012-11-07T00:21:02Z'))
      expect(solr_doc['published_earliest_dttsi']).to eq('2012-01-27T05:06:54Z')
      expect(solr_doc['published_latest_dttsi'  ]).to eq('2012-11-07T00:59:39Z')
      expect(solr_doc['published_dttsim'].first).to eq(solr_doc['published_earliest_dttsi'])
      expect(solr_doc['published_dttsim'].last ).to eq(solr_doc['published_latest_dttsi'  ])
      expect(solr_doc['published_dttsim'].size ).to eq(3) # not 4 because 1 deduplicated value removed!
      expect(solr_doc['opened_earliest_dttsi']).to eq('2012-10-29T23:30:07Z') #  2012-10-29T16:30:07-0700
      expect(solr_doc['opened_latest_dttsi'  ]).to eq('2012-11-07T00:21:02Z') #  2012-11-06T16:21:02-0800
    end
    it 'should skip the versioning related steps if a new version has not been opened' do
      @item = instantiate_fixture('druid:ab123cd4567', ProcessableOnlyItem)
      allow(Dor::WorkflowService).to receive(:query_lifecycle).and_return(Nokogiri::XML('<?xml version="1.0" encoding="UTF-8"?>
      <lifecycle objectId="druid:gv054hp4128">
      <milestone date="2012-11-06T16:30:03-0800">submitted</milestone>
      <milestone date="2012-11-06T16:35:00-0800">described</milestone>
      <milestone date="2012-11-06T16:59:39-0800" version="3">published</milestone>
      <milestone date="2012-11-06T16:59:39-0800">published</milestone>
      </lifecycle>'))
      solr_doc = @item.to_solr
      expect(solr_doc['opened_dttsim']).to be_nil
    end
    it 'should create a modified_latest date field' do
      @item = instantiate_fixture('druid:ab123cd4567', ProcessableOnlyItem)
      solr_doc = @item.to_solr
      # the facet field should have a date in it.
      expect(solr_doc['modified_latest_dttsi']).to match /^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ$/
    end
    it 'should create a version field for each version, including the version number, tag and description' do
      expect(Dor.logger).to receive(:warn).with(/Cannot index druid:ab123cd4567\.descMetadata.*Dor::Item#generate_dublin_core produced incorrect xml/)
      solr_doc = @item.to_solr
      expect(solr_doc['versions_ssm'].length).to be > 1
      expect(solr_doc['versions_ssm']).to include('4;2.2.0;Another typo')
    end
    it 'should handle a missing description for a version' do
      dsxml = '
      <versionMetadata objectId="druid:ab123cd4567">
      <version versionId="1" tag="1.0.0">
      <description>Initial version</description>
      </version>
      <version versionId="2" tag="2.0.0">
      <description>Replacing main PDF</description>
      </version>
      <version versionId="3" tag="2.1.0">
      <description>Fixed title typo</description>
      </version>
      <version versionId="4" tag="2.2.0">
      </version>
      </versionMetadata>
      '
      allow(@item).to receive(:versionMetadata).and_return(Dor::VersionMetadataDS.from_xml(dsxml))
      expect(Dor.logger).to receive(:warn).with(/Cannot index druid:ab123cd4567\.descMetadata.*Dor::Item#generate_dublin_core produced incorrect xml/)
      solr_doc = @item.to_solr
      expect(solr_doc['versions_ssm']).to include('4;2.2.0;')
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
      expect(Dor::WorkflowService).to receive(:query_lifecycle).and_return(xml)
      expect(@versionMD).to receive(:current_version_id).and_return('4')
      expect(@item.status).to eq('v4 In accessioning (described, published)')
    end
    it 'should generate a status string' do
      expect(Dor::WorkflowService).to receive(:query_lifecycle).and_return(@gv054hp4128)
      expect(@versionMD).to receive(:current_version_id).and_return('3')
      expect(@item.status).to eq('v3 In accessioning (described, published)')
    end
    it 'should generate a status string' do
      expect(Dor::WorkflowService).to receive(:query_lifecycle).and_return(@gv054hp4128)
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
      expect(Dor::WorkflowService).to receive(:query_lifecycle).and_return(@xml)
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
      expect(Dor::WorkflowService).to receive(:create_workflow).with('dor', 'druid:ab123cd4567', 'accessionWF', '<xml/>', {:create_ds => true, :lane_id => 'fast'})
      item.create_workflow('accessionWF')
    end
  end

  describe '#simplified_status_code_disp_txt' do
    it "trims off parens but doesn't harm the strings otherwise" do
      expect(@item.simplified_status_code_disp_txt(2)).to eq('In accessioning')
      expect(@item.simplified_status_code_disp_txt(3)).to eq('In accessioning')
    end
  end
end
