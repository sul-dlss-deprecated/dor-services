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
    <file format="TIFF" id="gw177fc7976_00_0001.tif" mimetype="image/tiff" preserve="yes" publish="no" shelve="no" size="81630420">
    <imageData height="4580" width="5939"/>
    <checksum type="md5">81ccd17bccf349581b779615e82a0366</checksum>
    <checksum type="sha1">12586b624540031bfa3d153299160c4885c3508c</checksum>
    </file>
    </resource>
    </contentMetadata>'
    allow(Dor::Item).to receive(:find).and_return(@item)

  end
  describe 'add_resource' do
    before(:all){
      file={}
      file[:name]='new_file.jp2'
      file[:shelve]='no'
      file[:publish]='no'
      file[:preserve]='no'
      @files=Array.new
      @files[0]=file
    }

    before(:each) do
      allow(Dor::Item).to receive(:save).and_return(true)
    end

    it 'should add a resource with default type="file"' do
      @item.contentMetadata.add_resource(@files,'resource',1)
      xml=@item.contentMetadata.ng_xml
      expect(xml.search('//resource[@id=\'resource\']').length).to eq(1)
      xml.search('//resource[@id=\'resource\']').each do |node|
        expect(node['id']).to eq('resource')
        expect(node['type']).to eq('file')
        expect(node['sequence']).to eq('1')
      end
    end

    it 'should add a resource with a type="image"' do
      @item.contentMetadata.add_resource(@files,'resource',1,'image')
      xml=@item.contentMetadata.ng_xml
      expect(xml.search('//resource[@id=\'resource\']').length).to eq(1)
      xml.search('//resource[@id=\'resource\']').each do |node|
        expect(node['id']).to eq('resource')
        expect(node['type']).to eq('image')
        expect(node['sequence']).to eq('1')
      end
    end


    it 'should add a resource with a checksum' do
      @files[0][:md5]='123456'
      @files[0][:sha1]='56789'
      @item.contentMetadata.add_resource(@files,'resource',1)
      xml=@item.contentMetadata.ng_xml
      checksums=xml.search('//file[@id=\'new_file.jp2\']//checksum')
      expect(checksums.length).to eq(2)
      checksums.each do |checksum|
        if checksum['type'] == 'md5'
          expect(checksum.content).to eq('123456')
        else
          expect(checksum.content).to eq('56789')
        end
      end
    end
    describe 'remove_resource' do
      it 'should remove the only resource' do
        @item.contentMetadata.remove_resource('0001')
        xml=@item.contentMetadata.ng_xml
        expect(xml.search('//resource').length).to eq(0)
      end
      it 'should remove one resource and renumber remaining resources' do
        file={}
        file[:name]='new_file.jp2'
        file[:shelve]='no'
        file[:publish]='no'
        file[:preserve]='no'
        @files=Array.new
        @files[0]=file
        allow(Dor::Item).to receive(:save).and_return(true)

        @item.contentMetadata.add_resource(@files,'resource',1)
        @item.contentMetadata.remove_resource('resource')
        xml=@item.contentMetadata.ng_xml
        resources=xml.search('//resource')
        expect(resources.length).to eq(1)
        expect(resources.first()['sequence']).to eq('1')

      end
    end
    end
    describe 'remove_file' do
      it 'should remove the file' do
        @item.contentMetadata.remove_file('gw177fc7976_00_0001.tif')
        xml=@item.contentMetadata.ng_xml
        expect(xml.search('//file').length).to eq(1)
      end
    end
    describe 'add_file' do
      before(:all){
        @file={}
        @file[:name]='new_file.jp2'
        @file[:shelve]='no'
        @file[:publish]='no'
        @file[:preserve]='no'
        @file[:size]='12345'
      }
      it 'should add a file to the resource' do
        @item.contentMetadata.add_file(@file,'0001')
        xml=@item.contentMetadata.ng_xml
        files=xml.search('//resource[@id=\'0001\']/file')
        expect(files.length).to eq(3)
        expect(xml.search('//file[@id=\'new_file.jp2\']').length).to eq(1)
        new_file=xml.search('//file[@id=\'new_file.jp2\']').first
        expect(new_file['shelve']).to eq('no')
        expect(new_file['publish']).to eq('no')
        expect(new_file['preserve']).to eq('no')
        expect(new_file['size']).to eq('12345')
      end
    end
    describe 'update_file' do
      before(:all){
        @file={}
        @file[:name]='new_file.jp2'
        @file[:shelve]='no'
        @file[:publish]='no'
        @file[:preserve]='no'
        @file[:size]='12345'
      }
      it 'should modify an existing file record' do
        @item.contentMetadata.update_file(@file,'gw177fc7976_05_0001.jp2')
        xml = @item.contentMetadata.ng_xml
        file=xml.search('//file[@id=\'new_file.jp2\']')
        expect(file.length).to eq(1)
        file=file.first
        expect(file['shelve']).to eq('no')
        expect(file['publish']).to eq('no')
        expect(file['preserve']).to eq('no')
        expect(file['size']).to eq('12345')
      end
      it 'should error out if there isnt an existing record to modify' do
        expect { @item.contentMetadata.update_file(@file,'gw177fc7976_05_0001_different.jp2')}.to raise_error
      end
    end
    describe 'rename_file' do
      it 'should update the file id' do
        @item.contentMetadata.rename_file('gw177fc7976_05_0001.jp2','test.jp2')
        xml = @item.contentMetadata.ng_xml
        file=xml.search('//file[@id=\'test.jp2\']')
        expect(file.length).to eq(1)
      end
    end
    describe 'move_resource' do
      it 'should renumber the resources correctly' do
        file={}
        file[:name]='new_file.jp2'
        file[:shelve]='no'
        file[:publish]='no'
        file[:preserve]='no'
        @files=Array.new
        @files[0]=file
        @item.contentMetadata.add_resource(@files,'resource',1)
        @item.contentMetadata.move_resource('0001','2')
      end
    end
    describe 'update resource label' do
      it 'should update an existing label' do
        @item.contentMetadata.update_resource_label '0001', 'an old label'
        @item.contentMetadata.update_resource_label '0001', 'label!'
        xml = @item.contentMetadata.ng_xml
        labels=xml.search('//resource[@id=\'0001\']/label')
        expect(labels.length).to eq(1)
        expect(labels.first.content).to eq('label!')
      end
      it 'should add a new label' do
         @item.contentMetadata.update_resource_label '0001', 'label!'
          xml = @item.contentMetadata.ng_xml
          labels=xml.search('//resource[@id=\'0001\']/label')
          expect(labels.length).to eq(1)
      end
    end
    describe 'update_resource_type' do
      it 'should update an existing type' do
        @item.contentMetadata.update_resource_label '0001', 'book'
      end
    end
    describe 'to_solr' do
      it 'should generate a shelved file count' do
        doc=@item.contentMetadata.to_solr
        expect(doc['shelved_content_file_count_display'].first).to eq('1')
      end
      it 'should generate a resource count' do
        doc=@item.contentMetadata.to_solr
        expect(doc['resource_count_display'].first).to eq('1')
      end
      it 'should generate a file count' do
        doc=@item.contentMetadata.to_solr
        expect(doc['content_file_count_display'].first).to eq('2')
      end
      it 'should generate a field called image_resource_count' do
        doc=@item.contentMetadata.to_solr
        expect(doc['image_resource_count_display'].first).to eq('1')
      end
      it 'should generate a field called first_shelved_image' do
        doc=@item.contentMetadata.to_solr
        expect(doc['first_shelved_image_display'].first).to eq('gw177fc7976_05_0001.jp2')
      end
      it 'should generate a field call preserved_size_display' do
        doc=@item.contentMetadata.to_solr
        expect(doc['preserved_size_t'].first).to eq('86774303')
      end
    end
  describe 'set_content_type' do
    it 'should change the content type and the resource types' do
      @item.contentMetadata.set_content_type 'map', 'image', 'book', 'page'
      expect(@item.contentMetadata.ng_xml.search('//contentMetadata[@type=\'book\']').length).to eq(1)
      expect(@item.contentMetadata.ng_xml.search('//contentMetadata/resource[@type=\'page\']').length).to eq(1)
    end
  end
  describe 'get stacks value' do
    it 'should read the stacks value' do
      expect(@item.contentMetadata.stacks).to eq(["/specialstack"])
    end
  end
  describe 'add_virtual_resource' do
    it 'should add a virtual resource to the target child item' do
      child_druid = 'bb273jy3359'
      child_resource = Nokogiri::XML('
      <resource type="image" sequence="1" id="bb273jy3359_1">
        <label>Image 1</label>
        <file preserve="yes" shelve="no" publish="no" id="00006672_0007.tif" mimetype="image/tiff" size="27469533">
          <checksum type="md5">4e3bc269ab1fc5dc5a37cde75d220394</checksum>
          <checksum type="sha1">63688070add0f246bffb1d9739a9d4c6b5e0e5ef</checksum>
          <imageData width="3883" height="2907"/>
        </file>
        <file id="00006672_0007.jp2" mimetype="image/jp2" size="2124513" preserve="no" publish="yes" shelve="yes">
          <checksum type="md5">65fad5e9dbaaef1130e500f6472a7200</checksum>
          <checksum type="sha1">374d1b71522acf10bbe9fff6af5f50dd5de3022c</checksum>
          <imageData width="3883" height="2907"/>
        </file>
      </resource>
      ').root
    
      expect(@item.contentMetadata).to receive(:'content=').and_call_original
      @item.contentMetadata.add_virtual_resource(child_druid, child_resource)
      nodes = @item.contentMetadata.ng_xml.search('//resource[@id=\'ab123cd4567_2\']')
      expect(nodes.length).to eq(1)
      node = nodes.first
      expect(node['id'      ]).to eq('ab123cd4567_2')
      expect(node['type'    ]).to eq('image')
      expect(node['sequence']).to eq('2')
    
      expect(nodes.search('label').length).to eq(0)

      externalFile = nodes.search('externalFile')
      expect(externalFile.length).to eq(1)
      expect(externalFile.first['objectId']).to eq('bb273jy3359')
      expect(externalFile.first['resourceId']).to eq('bb273jy3359_1')
      expect(externalFile.first['fileId']).to eq('00006672_0007.jp2')
      expect(externalFile.first['mimetype']).to eq('image/jp2')
    
      relationship = nodes.search('relationship')
      expect(relationship.length).to eq(1)
      expect(relationship.first['type']).to eq('alsoAvailableAs')
      expect(relationship.first['objectId']).to eq('bb273jy3359')
    end

    it 'should add a virtual resource to the target child item even if it has 2 published files' do
      child_druid = 'bb273jy3359'
      child_resource = Nokogiri::XML('
      <resource type="image" sequence="1" id="bb273jy3359_1">
        <label>Image 1</label>
        <file preserve="yes" shelve="no" publish="yes" id="00006672_0007.tif" mimetype="image/tiff" size="27469533">
          <checksum type="md5">4e3bc269ab1fc5dc5a37cde75d220394</checksum>
          <checksum type="sha1">63688070add0f246bffb1d9739a9d4c6b5e0e5ef</checksum>
          <imageData width="3883" height="2907"/>
        </file>
        <file id="00006672_0007.jp2" mimetype="image/jp2" size="2124513" preserve="no" publish="yes" shelve="yes">
          <checksum type="md5">65fad5e9dbaaef1130e500f6472a7200</checksum>
          <checksum type="sha1">374d1b71522acf10bbe9fff6af5f50dd5de3022c</checksum>
          <imageData width="3883" height="2907"/>
        </file>
      </resource>
      ').root

      expect(@item.contentMetadata).to receive(:'content=').and_call_original
      @item.contentMetadata.add_virtual_resource(child_druid, child_resource)
      nodes = @item.contentMetadata.ng_xml.search('//resource[@id=\'ab123cd4567_2\']')
      externalFile = nodes.search('externalFile')
      expect(externalFile.length).to eq(2)
      expect(externalFile[0]['mimetype']).to eq('image/tiff')
      expect(externalFile[1]['mimetype']).to eq('image/jp2')
    end

    it 'should add a virtual resource to an empty parent' do
      child_druid = 'bb273jy3359'
      child_resource = Nokogiri::XML('
      <resource type="image" sequence="1" id="bb273jy3359_1">
        <label>Image 1</label>
        <file id="00006672_0007.jp2" mimetype="image/jp2" preserve="no" publish="yes" shelve="yes">
          <imageData width="3883" height="2907"/>
        </file>
      </resource>
      ').root

      @item.contentMetadata.content = "<contentMetadata objectId='#{@item.pid}' type='image'/>"
      expect(@item.contentMetadata).to be_a(Dor::ContentMetadataDS)

      @item.contentMetadata.add_virtual_resource(child_druid, child_resource)
      nodes = @item.contentMetadata.ng_xml.search('//resource[@id="ab123cd4567_1"]')
      expect(nodes.size).to eq(1)
      expect(nodes.first[:sequence]).to eq('1')
      expect(nodes.first[:type]).to eq('image')
    end

    it 'should fail if missing contentMetadata entirely' do
      child_druid = 'bb273jy3359'
      child_resource = Nokogiri::XML('<resource/>').root
      @item.contentMetadata.content = nil
      expect { @item.contentMetadata.add_virtual_resource(child_druid, child_resource) }.to raise_error(ArgumentError)
    end
  end
end
