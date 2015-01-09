require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../lib/dor/models/contentable')

class MergeableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Contentable
end

describe Dor::Contentable do

  let(:primary_pid)   { 'druid:ab123cd0001' }
  let(:src1_pid) { 'druid:ab123cd0002' }
  let(:src2_pid) { 'druid:ab123cd0003' }

  let(:primary) {
    c = MergeableItem.new
    allow(c).to receive(:pid) { primary_pid }
    c
  }

  let(:src1) {
    c = MergeableItem.new
    allow(c).to receive(:pid) { src1_pid }
    c
  }

  let(:src2) {
    c = MergeableItem.new
    allow(c).to receive(:pid) { src2_pid }
    c
  }

  before(:each) do
    allow(primary.inner_object).to receive(:repository).and_return(double('frepo').as_null_object)
    allow(src1.inner_object).to receive(:repository).and_return(double('frepo').as_null_object)
    allow(Dor::Item).to receive(:find).with(src1_pid) { src1 }
    allow(Dor::Item).to receive(:find).with(src2_pid) { src2 }
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
      src1.contentMetadata.content = <<-XML
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

      primary.copy_file_resources([src1_pid])
      merged_cm = primary.contentMetadata.ng_xml
      expect(merged_cm.xpath('//resource').size).to eq(3)
      expect(merged_cm.xpath("//resource[@sequence = '2']").size).to eq(1)
      expect(merged_cm.xpath("//resource[@sequence = '3']").size).to eq(1)
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/@id").value).to  eq('image_2')
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/file/@id").value).to eq('image_b_2.jp2')
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/attr[@name = 'mergedFromPid']").text).to eq(src1_pid)
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/attr[@name = 'mergedFromResource']").text).to eq('ab123cd0002_1')
      expect(merged_cm.at_xpath("//resource[@sequence = '3']/@id").value).to eq('image_3')
      expect(merged_cm.at_xpath("//resource[@sequence = '3']/file/@id").value).to eq('image_c_3.jp2')
      expect(merged_cm.at_xpath("//resource[@sequence = '3']/attr[@name = 'mergedFromPid']").text).to eq(src1_pid)
      expect(merged_cm.at_xpath("//resource[@sequence = '3']/attr[@name = 'mergedFromResource']").text).to eq('ab123cd0002_2')
      expect(primary.contentMetadata).to be_changed
    end

    it "copies all the files within a resource to the primary object" do
      src1.contentMetadata.content = <<-XML
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

      primary.copy_file_resources([src1_pid])
      merged_cm = primary.contentMetadata.ng_xml
      expect(merged_cm.xpath('//resource').size).to eq(2)
      expect(merged_cm.xpath("//resource[@sequence = '2']").size).to eq(1)
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/@id").value).to eq('image_2')
      expect(merged_cm.xpath("//resource[@sequence = '2']/file").count).to eq(2)
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/file[@id='image_b_2.jp2']")).to be
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/file[last()]/@id").value).to eq('orig_2.tiff')
    end

    it "uses the contentMetadata objectId as the base id for copied resources if the secondary resource does not have a type attribute" do
      src1.contentMetadata.content = <<-XML
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

      primary.copy_file_resources([src1_pid])
      merged_cm = primary.contentMetadata.ng_xml
      expect(merged_cm.xpath('//resource').size).to eq(2)
      expect(merged_cm.xpath("//resource[@sequence = '2']").size).to eq(1)
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/@id").value).to eq('ab123cd0001_2')
    end


    it "raises an exception if new file name collides with an existing primary file" do
      primary.contentMetadata.content = <<-XML
      <?xml version="1.0"?>
      <contentMetadata objectId="ab123cd0001" type="map">
        <resource id="ab123cd0001_1" sequence="1" type="image">
          <file format="JPEG2000" id="image_a_2.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
            <imageData height="4580" width="5939"/>
            <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
            <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
          </file>
        </resource>
      </contentMetadata>
      XML

      src1.contentMetadata.content = <<-XML
      <?xml version="1.0"?>
      <contentMetadata objectId="ab123cd0002" type="map">
        <resource id="ab123cd0002_1" sequence="1" type="image">
          <file format="JPEG2000" id="image_a.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
            <imageData height="4580" width="5939"/>
            <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18xxxx</checksum>
            <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916xxx</checksum>
          </file>
        </resource>
      </contentMetadata>
      XML

      expect{primary.copy_file_resources([src1_pid])}.to raise_error Dor::Exception
    end

    it "processes more than one source object at a time" do
      src1.contentMetadata.content = <<-XML
      <?xml version="1.0"?>
      <contentMetadata objectId="ab123cd0002" type="map">
        <resource id="ab123cd0002_1" sequence="1" type="image">
          <file format="JPEG2000" id="image_b.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
            <imageData height="4580" width="5939"/>
            <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
            <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
          </file>
        </resource>
      </contentMetadata>
      XML

      src2.contentMetadata.content = <<-XML
      <?xml version="1.0"?>
      <contentMetadata objectId="ab123cd0003" type="map">
        <resource id="ab123cd0003_1" sequence="1" type="image">
          <file format="JPEG2000" id="image_c.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
            <imageData height="4580" width="5939"/>
            <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
            <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
          </file>
        </resource>
      </contentMetadata>
      XML

      primary.copy_file_resources([src1_pid, src2_pid])
      merged_cm = primary.contentMetadata.ng_xml
      expect(merged_cm.xpath('//resource').size).to eq(3)
      expect(merged_cm.xpath("//resource[@sequence = '2']").size).to eq(1)
      expect(merged_cm.xpath("//resource[@sequence = '3']").size).to eq(1)
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/@id").value).to  eq('image_2')
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/file/@id").value).to eq('image_b_2.jp2')
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/attr[@name = 'mergedFromPid']").text).to eq(src1_pid)
      expect(merged_cm.at_xpath("//resource[@sequence = '2']/attr[@name = 'mergedFromResource']").text).to eq('ab123cd0002_1')
      expect(merged_cm.at_xpath("//resource[@sequence = '3']/@id").value).to eq('image_3')
      expect(merged_cm.at_xpath("//resource[@sequence = '3']/file/@id").value).to eq('image_c_3.jp2')
      expect(merged_cm.at_xpath("//resource[@sequence = '3']/attr[@name = 'mergedFromPid']").text).to eq(src2_pid)
      expect(merged_cm.at_xpath("//resource[@sequence = '3']/attr[@name = 'mergedFromResource']").text).to eq('ab123cd0003_1')
    end

    context "<label> processing" do

      it "copies resource level labels" do
        src1.contentMetadata.content = <<-XML
        <?xml version="1.0"?>
        <contentMetadata objectId="ab123cd0002" type="map">
          <resource id="resource-has-no-type-attribute" sequence="1">
            <label>Image From the Lab</label>
            <file format="JPEG2000" id="img2.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
              <imageData height="4580" width="5939"/>
              <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
              <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
            </file>
          </resource>
        </contentMetadata>
        XML

        primary.copy_file_resources([src1_pid])
        merged_cm = primary.contentMetadata.ng_xml
        expect(merged_cm.xpath('//resource').size).to eq(2)
        expect(merged_cm.xpath("//resource[@sequence = '2']").size).to eq(1)
        expect(merged_cm.at_xpath("//resource[@sequence = '2']/label").text).to eq('Image From the Lab')
      end

      it "detects sequence numbers at the end of the label and increments them when appending to primary contentMetadata" do
        src1.contentMetadata.content = <<-XML
        <?xml version="1.0"?>
        <contentMetadata objectId="ab123cd0002" type="map">
          <resource id="resource-has-no-type-attribute" sequence="1">
            <label>Image 1</label>
            <file format="JPEG2000" id="img2.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
              <imageData height="4580" width="5939"/>
              <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
              <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
            </file>
          </resource>
        </contentMetadata>
        XML

        primary.copy_file_resources([src1_pid])
        merged_cm = primary.contentMetadata.ng_xml
        expect(merged_cm.xpath('//resource').size).to eq(2)
        expect(merged_cm.xpath("//resource[@sequence = '2']").size).to eq(1)
        expect(merged_cm.at_xpath("//resource[@sequence = '2']/label").text).to eq('Image 2')
      end
    end

  end
end