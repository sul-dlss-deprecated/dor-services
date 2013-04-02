require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'dor/services/technical_metadata_service'
require 'moab_stanford'
require 'fakeweb'

describe Dor::TechnicalMetadataService do

  before(:all) do
    @fixtures=fixtures=Pathname(File.dirname(__FILE__)).join("../fixtures")
    Dor::Config.push! do
      sdr.local_workspace_root fixtures.join("workspace").to_s
    end
    @sdr_repo = @fixtures.join('sdr_repo')
    @workspace_pathname = Pathname(Dor::Config.sdr.local_workspace_root)

    @object_ids = %w(dd116zh0343 du000ps9999 jq937jp0017)
    @druid_tool = Hash.new
    @inventory_differences = Hash.new
    @deltas = Hash.new
    @new_files = Hash.new
    @repo_techmd = Hash.new
    @new_file_techmd = Hash.new
    @expected_techmd = Hash.new

    @object_ids.each do |id|
      druid = "druid:#{id}"
      @druid_tool[id] = DruidTools::Druid.new(druid,@workspace_pathname.to_s)
      repo_content_pathname = @fixtures.join('sdr_repo',id,'v0001', 'data','content')
      work_content_pathname = Pathname(@druid_tool[id].content_dir)
      repo_content_inventory = Moab::FileGroup.new(:group_id=>'content').group_from_directory(repo_content_pathname)
      work_content_inventory = Moab::FileGroup.new.group_from_directory(work_content_pathname)
      @inventory_differences[id] = Moab::FileGroupDifference.new()
      @inventory_differences[id].compare_file_groups(repo_content_inventory, work_content_inventory)
      @deltas[id] = @inventory_differences[id].file_deltas
      @new_files[id] = Dor::TechnicalMetadataService.get_new_files(@deltas[id])
      @repo_techmd[id] = @fixtures.join('sdr_repo',id,'v0001', 'data','metadata', 'technicalMetadata.xml').read
      @new_file_techmd[id] = Dor::TechnicalMetadataService.get_new_technical_metadata(druid, @new_files[id])
      @expected_techmd[id] = Pathname(@druid_tool[id].metadata_dir).join('technicalMetadata.xml').read
    end

  end

  after(:all) do
    @object_ids.each do |id|
      temp_pathname = Pathname(@druid_tool[id].temp_dir(false) )
      temp_pathname.rmtree if temp_pathname.exist?
    end
  end

  specify "Dor::TechnicalMetadataService.add_update_technical_metadata" do
    @object_ids.each do |id|
      dor_item = mock(Dor::Item)
      dor_item.stub(:pid).and_return("druid:#{id}")
      Dor::TechnicalMetadataService.should_receive(:get_content_group_diff).with(dor_item).
          and_return(@inventory_differences[id])
      Dor::TechnicalMetadataService.should_receive(:get_file_deltas).with(@inventory_differences[id]).and_return(@deltas[id])
      Dor::TechnicalMetadataService.should_receive(:get_old_technical_metadata).with(dor_item).
          and_return(@repo_techmd[id])
      Dor::TechnicalMetadataService.should_receive(:get_new_technical_metadata).with(
          dor_item.pid, an_instance_of(Array)).
          and_return(@new_file_techmd[id])
      mock_datastream = mock("datastream")
      ds_hash = {"technicalMetadata" => mock_datastream}
      dor_item.stub(:datastreams).and_return(ds_hash)
      unless @inventory_differences[id].difference_count == 0
        mock_datastream.should_receive(:dsLabel=).with('Technical Metadata')
        mock_datastream.should_receive(:content=).with(/<technicalMetadata/)
        mock_datastream.should_receive(:save)
      end
      Dor::TechnicalMetadataService.add_update_technical_metadata(dor_item)
    end
  end

  specify "Dor::TechnicalMetadataService.get_content_group_diff(dor_item)" do
    @object_ids.each do |id|
      group_diff = @inventory_differences[id]
      inventory_diff = Moab::FileInventoryDifference.new(
          :digital_object_id=>"druid:#{id}",
          :basis=>"old_content_metadata",
          :other=>"new_content_metadata",
          :report_datetime => Time.now.to_s
      )
      inventory_diff.group_differences << group_diff
      dor_item = mock(Dor::Item)
      dor_item.stub(:get_content_diff).with('all').and_return(inventory_diff.to_xml)
      content_group_diff = Dor::TechnicalMetadataService.get_content_group_diff(dor_item)
      content_group_diff.to_xml.should == group_diff.to_xml
    end
  end

  specify "Dor::TechnicalMetadataService.get_file_deltas(content_group_diff)" do
    @object_ids.each do |id|
      group_diff = @inventory_differences[id]
      inventory_diff = Moab::FileInventoryDifference.new(
          :digital_object_id=>"druid:#{id}",
          :basis=>"old_content_metadata",
          :other=>"new_content_metadata"
      )
      deltas = Dor::TechnicalMetadataService.get_file_deltas(group_diff)
      deltas.should == @deltas[id]
    end
  end

  specify "Dor::TechnicalMetadataService.get_new_files" do
    new_files = Dor::TechnicalMetadataService.get_new_files(@deltas['jq937jp0017'])
    new_files.should == ["page-2.jpg", "page-1.jpg"]
  end

  specify "Dor::TechnicalMetadataService.get_old_technical_metadata(dor_item)" do
    druid = 'druid:dd116zh0343'
    dor_item = mock(Dor::Item)
    dor_item.stub(:pid).and_return(druid)
    tech_md = "<technicalMetadata/>"
    Dor::TechnicalMetadataService.should_receive(:get_sdr_technical_metadata).with(druid).and_return(tech_md,nil)
    old_techmd = Dor::TechnicalMetadataService.get_old_technical_metadata(dor_item)
    old_techmd.should == tech_md
    Dor::TechnicalMetadataService.should_receive(:get_dor_technical_metadata).with(dor_item).and_return(tech_md)
    old_techmd = Dor::TechnicalMetadataService.get_old_technical_metadata(dor_item)
    old_techmd.should == tech_md
  end

  specify "Dor::TechnicalMetadataService.get_sdr_technical_metadata" do
    druid = "druid:du000ps9999"
    Dor::TechnicalMetadataService.stub(:get_sdr_metadata).with(druid, "technicalMetadata").
        and_raise(RestClient::ResourceNotFound)
    sdr_techmd = Dor::TechnicalMetadataService.get_sdr_technical_metadata(druid)
    sdr_techmd.should == nil

    Dor::TechnicalMetadataService.stub(:get_sdr_metadata).with(druid, "technicalMetadata").
        and_return('<technicalMetadata/>')
    sdr_techmd = Dor::TechnicalMetadataService.get_sdr_technical_metadata(druid)
    sdr_techmd.should == '<technicalMetadata/>'

    Dor::TechnicalMetadataService.stub(:get_sdr_metadata).with(druid, "technicalMetadata").
        and_return('<jhove/>')
    jhove_service = mock(JhoveService)
    JhoveService.stub(:new).and_return(jhove_service)
    jhove_service.stub(:upgrade_technical_metadata).and_return("upgraded techmd")
    sdr_techmd = Dor::TechnicalMetadataService.get_sdr_technical_metadata(druid)
    sdr_techmd.should == "upgraded techmd"
  end

  specify "Dor::TechnicalMetadataService.get_dor_technical_metadata" do
    dor_item = mock(Dor::Item)
    tech_ds = mock("techmd datastream")
    tech_ds.stub(:content).and_return('<technicalMetadata/>')
    datastreams = {'technicalMetadata'=>tech_ds}
    dor_item.stub(:datastreams).and_return(datastreams)

    tech_ds.stub(:new?).and_return(true)
    dor_techmd = Dor::TechnicalMetadataService.get_dor_technical_metadata(dor_item)
    dor_techmd.should == nil

    tech_ds.stub(:new?).and_return(false)
    dor_techmd = Dor::TechnicalMetadataService.get_dor_technical_metadata(dor_item)
    dor_techmd.should == '<technicalMetadata/>'

    tech_ds.stub(:content).and_return('<jhove/>')
    jhove_service = mock(JhoveService)
    JhoveService.stub(:new).and_return(jhove_service)
    jhove_service.stub(:upgrade_technical_metadata).and_return("upgraded techmd")
    dor_techmd = Dor::TechnicalMetadataService.get_dor_technical_metadata(dor_item)
    dor_techmd.should == "upgraded techmd"
  end

  specify "Dor::TechnicalMetadataService.get_sdr_metadata" do
    sdr_client = Dor::Config.sdr.rest_client
    FakeWeb.register_uri(:get, "#{sdr_client.url}/objects/druid:ab123cd4567/metadata/technicalMetadata.xml", :body => "<technicalMetadata>")
    response = Dor::TechnicalMetadataService.get_sdr_metadata("druid:ab123cd4567", "technicalMetadata")
    response.should == "<technicalMetadata>"
  end

  specify "Dor::TechnicalMetadataService.get_new_technical_metadata" do
    @object_ids.each do |id|
      new_techmd = Dor::TechnicalMetadataService.get_new_technical_metadata("druid:#{id}", @new_files[id])
      file_nodes = Nokogiri::XML(new_techmd).xpath('//file')
      case id
        when 'dd116zh0343'
          file_nodes.size.should == 6
        when 'du000ps9999'
          file_nodes.size.should == 0
        when 'jq937jp0017'
          file_nodes.size.should == 2
      end
    end
  end

  specify "Dor::TechnicalMetadataService.write_fileset" do
    @object_ids.each do |id|
      temp_dir = @druid_tool[id].temp_dir
      new_files = @new_files[id]
      filename = Dor::TechnicalMetadataService.write_fileset(temp_dir, new_files)
      if new_files.size > 0
        Pathname(filename).read.should == new_files.join("\n") + "\n"
      else
        Pathname(filename).read.should == ""
      end
    end

  end

  specify "Dor::TechnicalMetadataService.merge_file_nodes" do
    @object_ids.each do |id|
      old_techmd = @repo_techmd[id]
      new_techmd = @new_file_techmd[id]
      new_nodes = Dor::TechnicalMetadataService.get_file_nodes(new_techmd)
      deltas = @deltas[id]
      merged_nodes = Dor::TechnicalMetadataService.merge_file_nodes(old_techmd, new_techmd, deltas)
      case id
        when 'dd116zh0343'
          new_nodes.keys.sort. should == [
              "folder1PuSu/story3m.txt",
              "folder1PuSu/story5a.txt",
              "folder2PdSa/story8m.txt",
              "folder2PdSa/storyAa.txt",
              "folder3PaSd/storyDm.txt",
              "folder3PaSd/storyFa.txt"
          ]
          merged_nodes.keys.sort.should == [
              "folder1PuSu/story1u.txt",
              "folder1PuSu/story2rr.txt",
              "folder1PuSu/story3m.txt",
              "folder1PuSu/story5a.txt",
              "folder2PdSa/story6u.txt",
              "folder2PdSa/story7rr.txt",
              "folder2PdSa/story8m.txt",
              "folder2PdSa/storyAa.txt",
              "folder3PaSd/storyBu.txt",
              "folder3PaSd/storyCrr.txt",
              "folder3PaSd/storyDm.txt",
              "folder3PaSd/storyFa.txt"
          ]
        when 'du000ps9999'
          new_nodes.keys.sort. should == []
          merged_nodes.keys.sort.should == ["a1.txt", "a4.txt", "a5.txt", "a6.txt", "b1.txt"]
        when 'jq937jp0017'
          new_nodes.keys.sort. should == ["page-1.jpg", "page-2.jpg"]
          merged_nodes.keys.sort.should == ["page-1.jpg", "page-2.jpg", "page-3.jpg", "page-4.jpg", "title.jpg"]
      end
    end
  end


  specify "Dor::TechnicalMetadataService.get_file_nodes" do
    techmd = @repo_techmd["jq937jp0017"]
    nodes = Dor::TechnicalMetadataService.get_file_nodes(techmd)
    nodes.size.should == 6
    nodes.keys.sort.should == ["intro-1.jpg", "intro-2.jpg", "page-1.jpg", "page-2.jpg", "page-3.jpg", "title.jpg"]
    nodes["page-1.jpg"].should be_equivalent_to(<<-EOF
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

  specify "Dor::TechnicalMetadataService.build_technical_metadata(druid,merged_nodes)" do
    @object_ids.each do |id|
      old_techmd = @repo_techmd[id]
      new_techmd = @new_file_techmd[id]
      deltas = @deltas[id]
      merged_nodes = Dor::TechnicalMetadataService.merge_file_nodes(old_techmd, new_techmd, deltas)
      final_techmd = Dor::TechnicalMetadataService.build_technical_metadata("druid:#{id}",merged_nodes)
      final_techmd.gsub(/datetime=["'].*?["']/,'').should be_equivalent_to @expected_techmd[id].gsub(/datetime=["'].*?["']/,'')
    end
  end

end