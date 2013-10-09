require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../lib/dor/models/contentable')

class MergeableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Contentable
end

describe Dor::Contentable do

  let(:primary_pid)   { 'druid:ab123cd0001' }
  let(:secondary_pid) { 'druid:ab123cd0002' }

  let(:primary) {
    c = MergeableItem.new
    c.stub!(:pid).and_return(primary_pid)
    c
  }

  let(:secondary) {
    c = MergeableItem.new
    c.stub!(:pid).and_return(secondary_pid)
    c
  }

  before(:each) do
    primary.inner_object.stub!(:repository).and_return(stub('frepo').as_null_object)
    secondary.inner_object.stub!(:repository).and_return(stub('frepo').as_null_object)
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
    </contentMetadata>
    XML
  end

  describe "#copy_file_resources" do

    it "copies all the file resources from a secondary object to a primary object" do
      secondary.contentMetadata.content = <<-XML
      <?xml version="1.0"?>
      <contentMetadata objectId="ab123cd0002" type="map">
        <resource id="ab123cd0002_1" sequence="1" type="image">
          <file format="JPEG2000" id="image_b.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
            <imageData height="4580" width="5939"/>
            <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
            <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
          </file>
        </resource>
        <resource id="ab123cd0002_2" sequence="2" type="image">
          <file format="JPEG2000" id="image_c.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
            <imageData height="4580" width="5939"/>
            <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
            <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
          </file>
        </resource>
      </contentMetadata>
      XML

      primary.copy_file_resources(secondary)
      merged_cm = primary.contentMetadata.ng_xml
      expect(merged_cm.xpath('//resource').size).to eq(3)
      expect(merged_cm.xpath("//resource[@sequence = '2']").size).to eq(1)
      expect(merged_cm.xpath("//resource[@sequence = '3']").size).to eq(1)
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/@id").value).to  eq('image_2')
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/file/@id").value).to eq('image_b.jp2')
      expect(merged_cm.at_xpath("//resource[@sequence = '3']/@id").value).to eq('image_3')
      expect(merged_cm.at_xpath("//resource[@sequence = '3']/file/@id").value).to eq('image_c.jp2')
    end

    it "copies all the files within a resource to the primary object" do
      secondary.contentMetadata.content = <<-XML
      <?xml version="1.0"?>
      <contentMetadata objectId="ab123cd0002" type="map">
        <resource id="ab123cd0002_1" sequence="1" type="image">
          <file format="JPEG2000" id="image_b.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
            <imageData height="4580" width="5939"/>
            <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
            <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
          </file>
          <file format="TIFF" id="orig.tiff" mimetype="image/tiff" preserve="yes" publish="yes" shelve="yes" size="51438830">
            <imageData height="4580" width="5939"/>
            <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18x</checksum>
            <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916x</checksum>
          </file>
        </resource>
      </contentMetadata>
      XML

      primary.copy_file_resources(secondary)
      merged_cm = primary.contentMetadata.ng_xml
      expect(merged_cm.xpath('//resource').size).to eq(2)
      expect(merged_cm.xpath("//resource[@sequence = '2']").size).to eq(1)
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/@id").value).to eq('image_2')
      expect(merged_cm.xpath("//resource[@sequence = '2']/file").count).to eq(2)
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/file[@id='image_b.jp2']")).to be
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/file[last()]/@id").value).to eq('orig.tiff')
    end

    it "uses the contentMetadata objectId as the base id for copied resources if the secondary resource does not have a type attribute" do
      secondary.contentMetadata.content = <<-XML
      <?xml version="1.0"?>
      <contentMetadata objectId="ab123cd0002" type="map">
        <resource id="resource-has-no-type-attribute" sequence="1">
          <file format="JPEG2000" id="img2.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
            <imageData height="4580" width="5939"/>
            <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
            <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
          </file>
        </resource>
      </contentMetadata>
      XML

      primary.copy_file_resources(secondary)
      merged_cm = primary.contentMetadata.ng_xml
      expect(merged_cm.xpath('//resource').size).to eq(2)
      expect(merged_cm.xpath("//resource[@sequence = '2']").size).to eq(1)
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/@id").value).to eq('ab123cd0001_2')
    end

    it "skips files from the secondary object that already exist in the primary object" do
      # TODO may not be necessary since we'll only save the primary after all resources from a secondary are copied over
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
        <resource id="ab123cd0002_2" sequence="2" type="image">
          <file format="JPEG2000" id="image_c.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
            <imageData height="4580" width="5939"/>
            <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
            <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
          </file>
        </resource>
      </contentMetadata>
      XML

      primary.copy_file_resources(secondary)
      merged_cm = primary.contentMetadata.ng_xml
      expect(merged_cm.xpath('//resource').size).to eq(2)
      expect(merged_cm.xpath("//resource[@sequence = '2']").size).to eq(1)
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/@id").value).to  eq('image_2')
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/file/@id").value).to eq('image_c.jp2')
    end

  end
end