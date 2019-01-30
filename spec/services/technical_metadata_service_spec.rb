# frozen_string_literal: true

require 'spec_helper'
require 'moab/stanford'

RSpec.describe Dor::TechnicalMetadataService do
  let(:object_ids) { %w(dd116zh0343 du000ps9999 jq937jp0017) }
  let(:druid_tool) { {} }

  before do
    fixtures = Pathname(File.dirname(__FILE__)).join('../fixtures')
    wsfixtures = fixtures.join('workspace').to_s
    Dor::Config.push! do
      sdr.local_workspace_root wsfixtures
    end

    @sdr_repo = fixtures.join('sdr_repo')
    @inventory_differences = {}
    @deltas      = {}
    @new_files   = {}
    @repo_techmd = {}
    @new_file_techmd = {}
    @expected_techmd = {}

    object_ids.each do |id|
      druid = "druid:#{id}"
      druid_tool[id] = DruidTools::Druid.new(druid, Pathname(wsfixtures).to_s)
      repo_content_pathname = fixtures.join('sdr_repo', id, 'v0001', 'data', 'content')
      work_content_pathname = Pathname(druid_tool[id].content_dir)
      repo_content_inventory = Moab::FileGroup.new(group_id: 'content').group_from_directory(repo_content_pathname)
      work_content_inventory = Moab::FileGroup.new.group_from_directory(work_content_pathname)
      @inventory_differences[id] = Moab::FileGroupDifference.new
      @inventory_differences[id].compare_file_groups(repo_content_inventory, work_content_inventory)
      @deltas[id] = @inventory_differences[id].file_deltas
      @new_files[id] = described_class.get_new_files(@deltas[id])
      @repo_techmd[id] = fixtures.join('sdr_repo', id, 'v0001', 'data', 'metadata', 'technicalMetadata.xml').read
      @new_file_techmd[id] = described_class.get_new_technical_metadata(druid, @new_files[id])
      @expected_techmd[id] = Pathname(druid_tool[id].metadata_dir).join('technicalMetadata.xml').read
    end
  end

  after do
    Dor::Config.pop!
  end

  after(:all) do
    object_ids = [] if object_ids.nil?
    object_ids.each do |id|
      temp_pathname = Pathname(druid_tool[id].temp_dir(false))
      temp_pathname.rmtree if temp_pathname.exist?
    end
  end

  specify 'Dor::TechnicalMetadataService.add_update_technical_metadata' do
    object_ids.each do |id|
      dor_item = double(Dor::Item)
      allow(dor_item).to receive(:pid).and_return("druid:#{id}")
      expect(described_class).to receive(:get_content_group_diff).with(dor_item).and_return(@inventory_differences[id])
      expect(described_class).to receive(:get_file_deltas).with(@inventory_differences[id]).and_return(@deltas[id])
      expect(described_class).to receive(:get_old_technical_metadata).with(dor_item).and_return(@repo_techmd[id])
      expect(described_class).to receive(:get_new_technical_metadata).with(dor_item.pid, an_instance_of(Array)).and_return(@new_file_techmd[id])
      mock_datastream = double('datastream')
      ds_hash = { 'technicalMetadata' => mock_datastream }
      allow(dor_item).to receive(:datastreams).and_return(ds_hash)
      unless @inventory_differences[id].difference_count == 0
        expect(mock_datastream).to receive(:dsLabel=).with('Technical Metadata')
        expect(mock_datastream).to receive(:content=).with(/<technicalMetadata/)
        expect(mock_datastream).to receive(:save)
      end
      described_class.add_update_technical_metadata(dor_item)
    end
  end

  describe 'Dor::TechnicalMetadataService.get_content_group_diff(dor_item)' do
    let(:contentMetadata) { instance_double(Dor::ContentMetadataDS, content: 'foo') }

    it 'calculates the differences' do
      object_ids.each do |id|
        group_diff = @inventory_differences[id]
        druid = "druid:#{id}"
        inventory_diff = Moab::FileInventoryDifference.new(
          digital_object_id: druid,
          basis: 'old_content_metadata',
          other: 'new_content_metadata',
          report_datetime: Time.now.utc.to_s
        )
        inventory_diff.group_differences << group_diff
        dor_item = instance_double(Dor::Item, contentMetadata: contentMetadata, pid: druid)
        allow(Sdr::Client).to receive(:get_content_diff).with(druid, 'foo', 'all').and_return(inventory_diff)
        content_group_diff = described_class.get_content_group_diff(dor_item)
        expect(content_group_diff.to_xml).to eq(group_diff.to_xml)
      end
    end
  end

  specify 'Dor::TechnicalMetadataService.get_content_group_diff(dor_item) without contentMetadata' do
    dor_item = instance_double(Dor::Item, contentMetadata: nil)
    content_group_diff = described_class.get_content_group_diff(dor_item)
    expect(content_group_diff.difference_count).to be_zero
  end

  specify 'Dor::TechnicalMetadataService.get_file_deltas(content_group_diff)' do
    object_ids.each do |id|
      group_diff = @inventory_differences[id]
      expect(described_class.get_file_deltas(group_diff)).to eq(@deltas[id])
    end
  end

  specify 'Dor::TechnicalMetadataService.get_new_files' do
    new_files = described_class.get_new_files(@deltas['jq937jp0017'])
    expect(new_files).to eq(['page-2.jpg', 'page-1.jpg'])
  end

  specify 'Dor::TechnicalMetadataService.get_old_technical_metadata(dor_item)' do
    druid = 'druid:dd116zh0343'
    dor_item = double(Dor::Item)
    allow(dor_item).to receive(:pid).and_return(druid)
    tech_md = '<technicalMetadata/>'
    expect(described_class).to receive(:get_sdr_technical_metadata).with(druid).and_return(tech_md, nil)
    old_techmd = described_class.get_old_technical_metadata(dor_item)
    expect(old_techmd).to eq(tech_md)
    expect(described_class).to receive(:get_dor_technical_metadata).with(dor_item).and_return(tech_md)
    old_techmd = described_class.get_old_technical_metadata(dor_item)
    expect(old_techmd).to eq(tech_md)
  end

  specify 'Dor::TechnicalMetadataService.get_sdr_technical_metadata' do
    druid = 'druid:du000ps9999'
    allow(Sdr::Client).to receive(:get_sdr_metadata).with(druid, 'technicalMetadata').and_return(nil)
    sdr_techmd = described_class.get_sdr_technical_metadata(druid)
    expect(sdr_techmd).to be_nil

    allow(described_class).to receive(:get_sdr_metadata).with(druid, 'technicalMetadata').and_return('<technicalMetadata/>')
    sdr_techmd = described_class.get_sdr_technical_metadata(druid)
    expect(sdr_techmd).to eq('<technicalMetadata/>')

    allow(described_class).to receive(:get_sdr_metadata).with(druid, 'technicalMetadata').and_return('<jhove/>')
    jhove_service = double(JhoveService)
    allow(JhoveService).to receive(:new).and_return(jhove_service)
    allow(jhove_service).to receive(:upgrade_technical_metadata).and_return('upgraded techmd')
    sdr_techmd = described_class.get_sdr_technical_metadata(druid)
    expect(sdr_techmd).to eq('upgraded techmd')
  end

  specify 'Dor::TechnicalMetadataService.get_dor_technical_metadata' do
    dor_item = double(Dor::Item)
    tech_ds  = double('techmd datastream')
    allow(tech_ds).to receive(:content).and_return('<technicalMetadata/>')
    datastreams = { 'technicalMetadata' => tech_ds }
    allow(dor_item).to receive(:datastreams).and_return(datastreams)

    allow(tech_ds).to receive(:new?).and_return(true)
    dor_techmd = described_class.get_dor_technical_metadata(dor_item)
    expect(dor_techmd).to be_nil

    allow(tech_ds).to receive(:new?).and_return(false)
    dor_techmd = described_class.get_dor_technical_metadata(dor_item)
    expect(dor_techmd).to eq('<technicalMetadata/>')

    allow(tech_ds).to receive(:content).and_return('<jhove/>')
    jhove_service = double(JhoveService)
    allow(JhoveService).to receive(:new).and_return(jhove_service)
    allow(jhove_service).to receive(:upgrade_technical_metadata).and_return('upgraded techmd')
    dor_techmd = described_class.get_dor_technical_metadata(dor_item)
    expect(dor_techmd).to eq('upgraded techmd')
  end

  specify 'Dor::TechnicalMetadataService.get_new_technical_metadata' do
    object_ids.each do |id|
      new_techmd = described_class.get_new_technical_metadata("druid:#{id}", @new_files[id])
      file_nodes = Nokogiri::XML(new_techmd).xpath('//file')
      case id
      when 'dd116zh0343'
        expect(file_nodes.size).to eq(6)
      when 'du000ps9999'
        expect(file_nodes.size).to eq(0)
      when 'jq937jp0017'
        expect(file_nodes.size).to eq(2)
      end
    end
  end

  specify 'Dor::TechnicalMetadataService.write_fileset' do
    object_ids.each do |id|
      temp_dir = druid_tool[id].temp_dir
      new_files = @new_files[id]
      filename = described_class.write_fileset(temp_dir, new_files)
      if new_files.size > 0
        expect(Pathname(filename).read).to eq(new_files.join("\n") + "\n")
      else
        expect(Pathname(filename).read).to eq('')
      end
    end
  end

  specify 'Dor::TechnicalMetadataService.merge_file_nodes' do
    object_ids.each do |id|
      old_techmd = @repo_techmd[id]
      new_techmd = @new_file_techmd[id]
      new_nodes = described_class.get_file_nodes(new_techmd)
      deltas = @deltas[id]
      merged_nodes = described_class.merge_file_nodes(old_techmd, new_techmd, deltas)
      case id
      when 'dd116zh0343'
        expect(new_nodes.keys.sort). to eq([
                                             'folder1PuSu/story3m.txt',
                                             'folder1PuSu/story5a.txt',
                                             'folder2PdSa/story8m.txt',
                                             'folder2PdSa/storyAa.txt',
                                             'folder3PaSd/storyDm.txt',
                                             'folder3PaSd/storyFa.txt'
                                           ])
        expect(merged_nodes.keys.sort).to eq([
                                               'folder1PuSu/story1u.txt',
                                               'folder1PuSu/story2rr.txt',
                                               'folder1PuSu/story3m.txt',
                                               'folder1PuSu/story5a.txt',
                                               'folder2PdSa/story6u.txt',
                                               'folder2PdSa/story7rr.txt',
                                               'folder2PdSa/story8m.txt',
                                               'folder2PdSa/storyAa.txt',
                                               'folder3PaSd/storyBu.txt',
                                               'folder3PaSd/storyCrr.txt',
                                               'folder3PaSd/storyDm.txt',
                                               'folder3PaSd/storyFa.txt'
                                             ])
      when 'du000ps9999'
        expect(new_nodes.keys.sort). to eq([])
        expect(merged_nodes.keys.sort).to eq(['a1.txt', 'a4.txt', 'a5.txt', 'a6.txt', 'b1.txt'])
      when 'jq937jp0017'
        expect(new_nodes.keys.sort). to eq(['page-1.jpg', 'page-2.jpg'])
        expect(merged_nodes.keys.sort).to eq(['page-1.jpg', 'page-2.jpg', 'page-3.jpg', 'page-4.jpg', 'title.jpg'])
      end
    end
  end

  specify 'Dor::TechnicalMetadataService.get_file_nodes' do
    techmd = @repo_techmd['jq937jp0017']
    nodes = described_class.get_file_nodes(techmd)
    expect(nodes.size).to eq(6)
    expect(nodes.keys.sort).to eq(['intro-1.jpg', 'intro-2.jpg', 'page-1.jpg', 'page-2.jpg', 'page-3.jpg', 'title.jpg'])
    expect(nodes['page-1.jpg']).to be_equivalent_to(<<-EOF
    <file id="page-1.jpg">
      <jhove:reportingModule release="1.2" date="2007-02-13">JPEG-hul</jhove:reportingModule>
      <jhove:format>JPEG</jhove:format>
      <jhove:version>1.01</jhove:version>
      <jhove:status>Well-Formed and valid</jhove:status>
      <jhove:sigMatch>
        <jhove:module>JPEG-hul</jhove:module>
      </jhove:sigMatch>
      <jhove:mimeType>image/jpeg</jhove:mimeType>
      <jhove:profiles>
        <jhove:profile>JFIF</jhove:profile>
      </jhove:profiles>
      <jhove:properties>
        <mix:mix>
          <mix:BasicDigitalObjectInformation>
            <mix:byteOrder>big_endian</mix:byteOrder>
            <mix:Compression>
              <mix:compressionScheme>6</mix:compressionScheme>
            </mix:Compression>
          </mix:BasicDigitalObjectInformation>
          <mix:BasicImageInformation>
            <mix:BasicImageCharacteristics>
              <mix:imageWidth>438</mix:imageWidth>
              <mix:imageHeight>478</mix:imageHeight>
              <mix:PhotometricInterpretation>
                <mix:colorSpace>6</mix:colorSpace>
              </mix:PhotometricInterpretation>
            </mix:BasicImageCharacteristics>
          </mix:BasicImageInformation>
          <mix:ImageAssessmentMetadata>
            <mix:SpatialMetrics>
              <mix:samplingFrequencyUnit>2</mix:samplingFrequencyUnit>
              <mix:xSamplingFrequency>
                <mix:numerator>72</mix:numerator>
              </mix:xSamplingFrequency>
              <mix:ySamplingFrequency>
                <mix:numerator>72</mix:numerator>
              </mix:ySamplingFrequency>
            </mix:SpatialMetrics>
            <mix:ImageColorEncoding>
              <mix:bitsPerSample>
                <mix:bitsPerSampleValue>8,8,8</mix:bitsPerSampleValue>
                <mix:bitsPerSampleUnit>integer</mix:bitsPerSampleUnit>
              </mix:bitsPerSample>
              <mix:samplesPerPixel>3</mix:samplesPerPixel>
            </mix:ImageColorEncoding>
          </mix:ImageAssessmentMetadata>
        </mix:mix>
      </jhove:properties>
    </file>
    EOF
                                                   )
  end

  specify 'Dor::TechnicalMetadataService.build_technical_metadata(druid,merged_nodes)' do
    object_ids.each do |id|
      old_techmd = @repo_techmd[id]
      new_techmd = @new_file_techmd[id]
      deltas = @deltas[id]
      merged_nodes = described_class.merge_file_nodes(old_techmd, new_techmd, deltas)

      # the final and expected_techmd need to be scrubbed of dates in a couple spots for the comparison to match since these will vary from test run to test run
      final_techmd = described_class.build_technical_metadata("druid:#{id}", merged_nodes).gsub(/datetime=["'].*?["']/, '').gsub(/<jhove:lastModified>.*?<\/jhove:lastModified>/, '')
      expected_techmd = @expected_techmd[id].gsub(/datetime=["'].*?["']/, '').gsub(/<jhove:lastModified>.*?<\/jhove:lastModified>/, '')
      expect(final_techmd).to be_equivalent_to expected_techmd
    end
  end
end
