require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'tmpdir'

class MergeableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Contentable
end


describe Dor::MergeService do

  let(:workspace) { Dir.mktmpdir }

  let(:primary_pid)   { 'druid:ab123cd0001' }
  let(:secondary_pid) { 'druid:ab123cd0002' }

  let(:primary) {
    c = MergeableItem.new
    allow(c).to receive(:pid).and_return(primary_pid)
    allow(c.inner_object).to receive(:repository).and_return(double('frepo').as_null_object)
    c
  }

  let(:secondary) {
    c = MergeableItem.new
    allow(c).to receive(:pid).and_return(secondary_pid)
    allow(c.inner_object).to receive(:repository).and_return(double('frepo').as_null_object)
    c
  }

  let(:pri_druid_tree) { DruidTools::Druid.new primary_pid, workspace }
  let(:sec_druid_tree) { DruidTools::Druid.new secondary_pid, workspace }

  def create_tempfile(path, filename)
    File.open(File.join(path, filename), 'w') do |tf1|
      tf1.write 'junk'
    end
  end

  before(:each) do
    Dor::Config.push! do |config|
      config.stacks.local_workspace_root workspace
      config.sdr.local_workspace_root workspace
    end
  end

  after(:each) do
    unstub_config
    FileUtils.remove_entry workspace
  end

  describe "#copy_workspace_content" do

    before(:each) do
      primary.contentMetadata.content = <<-XML
      <?xml version="1.0"?>
      <contentMetadata objectId="ab123cd0001" type="map">
        <resource id="ab123cd0001_1" sequence="1" type="image">
          <file format="JPEG2000" id="image_a.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
            <imageData height="4580" width="5939"/>
            <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
            <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
          </file>
        </resource>
        <resource id="image_2" sequence="2" type="image">
          <attr name="mergedFromPid">druid:ab123cd0002</attr>
          <attr name="mergedFromResource">ab123cd0002_1</attr>
          <file format="JPEG2000" id="image_a_2.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
            <imageData height="4580" width="5939"/>
            <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
            <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
          </file>
        </resource>
      </contentMetadata>
      XML

      allow(Dor::Item).to receive(:find).with(primary_pid) { primary }
      allow(Dor::Item).to receive(:find).with(secondary_pid) { secondary }
      pri_druid_tree.mkdir
      create_tempfile pri_druid_tree.path, 'image_a.jp2'
    end

    it "copies the content in the workspace from the secondary object to the primary" do
      secondary.contentMetadata.content = <<-XML
      <?xml version="1.0"?>
      <contentMetadata objectId="ab123cd0002" type="map">
        <resource id="ab123cd0002_1" sequence="1" type="image">
          <file format="JPEG2000" id="image_a.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
            <imageData height="4580" width="5939"/>
            <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
            <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
          </file>
        </resource>
      </contentMetadata>
      XML

      sec_druid_tree.mkdir
      create_tempfile sec_druid_tree.path, 'image_a.jp2'

      ms = Dor::MergeService.new primary_pid, [secondary_pid], 'some tag'
      ms.copy_workspace_content

      druid_primary = DruidTools::Druid.new primary_pid, Dor::Config.stacks.local_workspace_root
      expect(druid_primary.find_content 'image_a.jp2').to_not be_nil
      expect(druid_primary.find_content 'image_a_2.jp2').to_not be_nil
      expect(druid_primary.find_content 'image_a_2.jp2').to match(/image_a_2.jp2/)
    end
  end

end