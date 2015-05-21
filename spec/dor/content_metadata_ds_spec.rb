require 'spec_helper'

describe Dor::ContentMetadataDS do
  before(:each) { stub_config }
  after(:each)  { unstub_config }

  before(:each) do
    @item = instantiate_fixture('druid:ab123cd4567', Dor::Item)
    @item.contentMetadata.content='<?xml version="1.0"?>
    <contentMetadata objectId="druid:gw177fc7976" type="map" stacks="/specialstack">
    <resource id="0001" sequence="1" type="image">
    <file format="JPEG2000" id="gw177fc7976_05_0001.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
    <imageData height="4580" width="5939"/>
    <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
    <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
    </file>
    <file format="GIF" id="gw177fc7976_05_0001.gif" mimetype="image/gif" preserve="no" publish="no" shelve="no" size="4128877">
    <imageData height="4580" width="5939"/>
    <checksum type="md5">406d5d80fdd9ecc0352d339badb4a8fb</checksum>
    <checksum type="sha1">61940d4fad097cba98a3e9dd9f12a90dde0be1ac</checksum>
    </file>
    <file format="TIFF" id="gw177fc7976_00_0001.tif" mimetype="image/tiff" preserve="yes" publish="no" shelve="no" size="81630420">
    <imageData height="4580" width="5939"/>
    <checksum type="md5">81ccd17bccf349581b779615e82a0366</checksum>
    <checksum type="sha1">12586b624540031bfa3d153299160c4885c3508c</checksum>
    </file>
    </resource>
    </contentMetadata>'
    allow(Dor::Item).to receive(:find).and_return(@item)
    # allow(Dor::Item).to receive(:save).and_return(true)
    @file = {
      :name     => 'new_file.jp2',
      :shelve   => 'no',
      :publish  => 'no',
      :preserve => 'no',
      :size     => '12345'
    }
    @files = [@file]
    @cm = @item.contentMetadata
 #  expect(@cm).not_to receive(:save)
  end

  describe 'add_resource' do
    it 'should add a resource with default type="file"' do
      @cm.add_resource(@files,'resource',1)
      nodes=@cm.ng_xml.search('//resource[@id=\'resource\']')
      expect(nodes.length).to eq(1)
      node = nodes.first
      expect(node['id'      ]).to eq('resource')
      expect(node['type'    ]).to eq('file')
      expect(node['sequence']).to eq('1')
    end

    it 'should add a resource with a type="image"' do
      @cm.add_resource(@files,'resource',1,'image')
      nodes=@cm.ng_xml.search('//resource[@id=\'resource\']')
      expect(nodes.length).to eq(1)
      node = nodes.first
      expect(node['id']      ).to eq('resource')
      expect(node['type']    ).to eq('image')
      expect(node['sequence']).to eq('1')
    end

    it 'should add a resource with a checksum' do
      @files[0][:md5 ]='123456'
      @files[0][:sha1]='56789'
      @cm.add_resource(@files,'resource',1)
      checksums=@cm.ng_xml.search('//file[@id=\'new_file.jp2\']//checksum')
      expect(checksums.length).to eq(2)
      checksums.each do |checksum|
        expect(checksum.content).to eq(checksum['type'] == 'md5' ? '123456' : '56789')
      end
    end
  end
  describe 'remove_resource' do
    it 'should remove the only resource' do
      @cm.remove_resource('0001')
      expect(@cm.ng_xml.search('//resource').length).to eq(0)
    end
    it 'should remove one resource and renumber remaining resources' do
      @cm.add_resource(@files,'resource',1)
      @cm.remove_resource('resource')
      resources=@cm.ng_xml.search('//resource')
      expect(resources.length).to eq(1)
      expect(resources.first()['sequence']).to eq('1')
    end
  end
  describe 'remove_file' do
    it 'should remove the file' do
      @cm.remove_file('gw177fc7976_00_0001.tif')
      expect(@cm.ng_xml.search('//file').length).to eq(2)
    end
  end
  describe 'add_file' do
    it 'should add a file to the resource' do
      @cm.add_file(@file,'0001')
      xml=@cm.ng_xml
      hits=xml.search('//resource[@id=\'0001\']/file')
      expect(hits.length).to eq(4)
      expect(xml.search('//file[@id=\'new_file.jp2\']').length).to eq(1)
      new_file=xml.search('//file[@id=\'new_file.jp2\']').first
      expect(new_file['shelve'  ]).to eq('no')
      expect(new_file['publish' ]).to eq('no')
      expect(new_file['preserve']).to eq('no')
      expect(new_file['size'    ]).to eq('12345')
    end
  end
  describe 'update_file' do
    it 'should modify an existing file record' do
      @cm.update_file(@file,'gw177fc7976_05_0001.jp2')
      file=@cm.ng_xml.search('//file[@id=\'new_file.jp2\']')
      expect(file.length).to eq(1)
      file=file.first
      expect(file['shelve'  ]).to eq('no')
      expect(file['publish' ]).to eq('no')
      expect(file['preserve']).to eq('no')
      expect(file['size'    ]).to eq('12345')
    end
    it 'should error out if there isnt an existing record to modify' do
      expect { @cm.update_file(@file,'gw177fc7976_05_0001_different.jp2')}.to raise_error
    end
  end
  describe 'rename_file' do
    it 'should update the file id' do
      @cm.rename_file('gw177fc7976_05_0001.jp2','test.jp2')
      file=@cm.ng_xml.search('//file[@id=\'test.jp2\']')
      expect(file.length).to eq(1)
    end
  end
  describe 'move_resource' do
    it 'should renumber the resources correctly' do
      @cm.add_resource(@files,'resource',1)
      @cm.move_resource('0001','2')
      skip "No expectation defined!"
    end
  end
  describe 'update resource label' do
    it 'should update an existing label' do
      @cm.update_resource_label '0001', 'an old label'
      @cm.update_resource_label '0001', 'label!'
      labels = @cm.ng_xml.search('//resource[@id=\'0001\']/label')
      expect(labels.length).to eq(1)
      expect(labels.first.content).to eq('label!')
    end
    it 'should add a new label' do
      @cm.update_resource_label '0001', 'qbert!'
      labels = @cm.ng_xml.search('//resource[@id=\'0001\']/label')
      expect(labels.length).to eq(1)
      expect(labels.first.content).to eq('qbert!')
    end
  end
  describe 'update_resource_type' do
    it 'should update an existing type' do
      @cm.update_resource_type '0001', 'book'
      skip "No expectation defined!"
    end
  end
  describe 'to_solr' do
    before :each do
      @doc=@cm.to_solr
    end
    it 'should generate required fields' do
      expect(@doc[Solrizer.solr_name('shelved_content_file_count', :displayable)].first).to eq('1')
      expect(@doc[Solrizer.solr_name('resource_count', :displayable)].first).to eq('1')
      expect(@doc[Solrizer.solr_name('content_file_count', :displayable)].first).to eq('3')
      expect(@doc[Solrizer.solr_name('image_resource_count', :displayable)].first).to eq('1')
      expect(@doc[Solrizer.solr_name('first_shelved_image', :displayable)].first).to eq('gw177fc7976_05_0001.jp2')
      expect(@doc[Solrizer.solr_name('preserved_size', :searchable)].first).to eq('86774303')
    end
  end
  describe 'set_content_type' do
    it 'should change the content type and the resource types' do
      @cm.set_content_type 'map', 'image', 'book', 'page'
      expect(@cm.ng_xml.search('//contentMetadata[@type=\'book\']').length).to eq(1)
      expect(@cm.ng_xml.search('//contentMetadata/resource[@type=\'page\']').length).to eq(1)
    end
  end
  describe 'get stacks value' do
    it 'should read the stacks value' do
      expect(@cm.stacks).to eq(["/specialstack"])
    end
  end
end
