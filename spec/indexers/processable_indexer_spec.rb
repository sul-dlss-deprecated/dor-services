# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::ProcessableIndexer do
  let(:model) do
    Class.new(Dor::Abstract) do
      # include Dor::Itemizable
      include Dor::Processable
      # include Dor::Versionable
      # include Dor::Describable
    end
  end

  before { stub_config }
  after { unstub_config }
  let(:obj) { instantiate_fixture('druid:ab123cd4567', model) }
  let(:indexer) { described_class.new(resource: obj) }

  describe '#simplified_status_code_disp_txt' do
    it "trims off parens but doesn't harm the strings otherwise" do
      expect(indexer.send(:simplified_status_code_disp_txt, 2)).to eq('In accessioning')
      expect(indexer.send(:simplified_status_code_disp_txt, 3)).to eq('In accessioning')
    end
  end

  describe 'to_solr' do
    before do
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
      allow(Dor::Config.workflow.client).to receive(:query_lifecycle).and_return(xml)
      allow_any_instance_of(Dor::Workflow::Document).to receive(:to_solr).and_return(nil)
      versionMD = Dor::VersionMetadataDS.from_xml(dsxml)
      allow(obj).to receive(:versionMetadata).and_return(versionMD)
    end

    let(:doc) { indexer.to_solr }

    it 'includes the semicolon delimited version, an earliest published date and a status' do
      # lifecycle_display should have the semicolon delimited version
      expect(doc['lifecycle_ssim']).to include('published:2012-01-27T05:06:54Z;2')
      # published date should be the first published date
      expect(doc).to match a_hash_including('status_ssi' => 'v4 In accessioning (described, published)')
      expect(doc).to match a_hash_including('opened_dttsim' => including('2012-11-07T00:21:02Z'))
      expect(doc['published_earliest_dttsi']).to eq('2012-01-27T05:06:54Z')
      expect(doc['published_latest_dttsi']).to eq('2012-11-07T00:59:39Z')
      expect(doc['published_dttsim'].first).to eq(doc['published_earliest_dttsi'])
      expect(doc['published_dttsim'].last).to eq(doc['published_latest_dttsi'])
      expect(doc['published_dttsim'].size).to eq(3) # not 4 because 1 deduplicated value removed!
      expect(doc['opened_earliest_dttsi']).to eq('2012-10-29T23:30:07Z') #  2012-10-29T16:30:07-0700
      expect(doc['opened_latest_dttsi']).to eq('2012-11-07T00:21:02Z') #  2012-11-06T16:21:02-0800
    end

    it 'skips the versioning related steps if a new version has not been opened' do
      allow(Dor::Config.workflow.client).to receive(:query_lifecycle).and_return(Nokogiri::XML('<?xml version="1.0" encoding="UTF-8"?>
      <lifecycle objectId="druid:gv054hp4128">
      <milestone date="2012-11-06T16:30:03-0800">submitted</milestone>
      <milestone date="2012-11-06T16:35:00-0800">described</milestone>
      <milestone date="2012-11-06T16:59:39-0800" version="3">published</milestone>
      <milestone date="2012-11-06T16:59:39-0800">published</milestone>
      </lifecycle>'))
      expect(doc['opened_dttsim']).to be_nil
    end

    it 'creates a modified_latest date field' do
      # @item = instantiate_fixture('druid:ab123cd4567', ProcessableOnlyItem)
      # the facet field should have a date in it.
      expect(doc['modified_latest_dttsi']).to match(/^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ$/)
    end

    it 'creates a version field for each version, including the version number, tag and description' do
      expect(doc['versions_ssm'].length).to be > 1
      expect(doc['versions_ssm']).to include('4;2.2.0;Another typo')
    end

    it 'handles a missing description for a version' do
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
      allow(obj).to receive(:versionMetadata).and_return(Dor::VersionMetadataDS.from_xml(dsxml))
      expect(doc['versions_ssm']).to include('4;2.2.0;')
    end
  end
end
