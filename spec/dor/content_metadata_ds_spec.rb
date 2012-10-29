require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'
require 'equivalent-xml'
require 'dor/datastreams/content_metadata_ds'

describe Dor::ContentMetadataDS do
  before(:all) { stub_config }
  after(:all)  { unstub_config }

  before(:each) do
    @item = instantiate_fixture('druid:ab123cd4567', Dor::Item)
    @item.contentMetadata.content='<?xml version="1.0"?>
    <contentMetadata objectId="druid:gw177fc7976" type="map">
    <resource id="0001" sequence="1" type="image">
    <file format="JPEG2000" id="gw177fc7976_05_0001.jp2" mimetype="image/jp2" preserve="true" publish="true" shelve="true" size="5143883">
    <imageData height="4580" width="5939"/>
    <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
    <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
    </file>
    <file format="TIFF" id="gw177fc7976_00_0001.tif" mimetype="image/tiff" preserve="true" publish="false" shelve="false" size="81630420">
    <imageData height="4580" width="5939"/>
    <checksum type="md5">81ccd17bccf349581b779615e82a0366</checksum>
    <checksum type="sha1">12586b624540031bfa3d153299160c4885c3508c</checksum>
    </file>
    </resource>
    </contentMetadata>'
    Dor::Item.stub(:find).and_return(@item)
  end
  describe 'add_resource' do
    before(:all){
      file={}
      file[:name]='new_file.jp2'
      file[:shelve]='false'
      file[:publish]='false'
      file[:preserve]='false'
      @files=Array.new
      @files[0]=file
      Dor::Item.stub(:save).and_return(true)
    }
    it 'should add a resource' do
      @item.contentMetadata.add_resource(@files,'resource',1)
      xml=@item.contentMetadata.ng_xml
      xml.search('//resource[@id=\'resource\']').length.should ==1
      xml.search('//resource[@id=\'resource\']').each do |node|
        node['id'].should == 'resource'
        node['sequence'].should == '1'
      end
    end
    it 'should add a resource with a checksum' do
      @files[0][:md5]='123456'
      @files[0][:sha1]='56789'
      @item.contentMetadata.add_resource(@files,'resource',1)
      xml=@item.contentMetadata.ng_xml
      checksums=xml.search('//file[@id=\'new_file.jp2\']//checksum')
      checksums.length.should == 2
      checksums.each do | checksum|
        if checksum['type'] == 'md5'
          checksum.content.should == '123456'
        else
          checksum.content.should == '56789'
        end
      end
    end
    describe 'remove_resource' do
      it 'should remove the only resource' do
        @item.contentMetadata.remove_resource('0001')
        xml=@item.contentMetadata.ng_xml
        xml.search('//resource').length.should ==0
      end
      it 'should remove one resource and renumber remaining resources' do
        file={}
        file[:name]='new_file.jp2'
        file[:shelve]='false'
        file[:publish]='false'
        file[:preserve]='false'
        @files=Array.new
        @files[0]=file
        Dor::Item.stub(:save).and_return(true)

        @item.contentMetadata.add_resource(@files,'resource',1)
        @item.contentMetadata.remove_resource('resource')
        xml=@item.contentMetadata.ng_xml
        resources=xml.search('//resource')
        resources.length.should ==1
        resources.first()['sequence'].should == '1'
        
      end
    end
    describe 'remove_file' do
      it 'should remove the file' do
        @item.contentMetadata.remove_file('gw177fc7976_00_0001.tif')
        xml=@item.contentMetadata.ng_xml
        xml.search('//file').length.should ==1
      end
    end
    describe 'add_file' do
      before(:all){
        @file={}
        @file[:name]='new_file.jp2'
        @file[:shelve]='false'
        @file[:publish]='false'
        @file[:preserve]='false'
        @file[:size]='12345'
      }
      it 'should add a file to the resource' do
        @item.contentMetadata.add_file(@file,'0001')
        xml=@item.contentMetadata.ng_xml
        files=xml.search('//resource[@id=\'0001\']/file')
        files.length.should == 3
        xml.search('//file[@id=\'new_file.jp2\']').length.should == 1
        new_file=xml.search('//file[@id=\'new_file.jp2\']').first
        new_file['shelve'].should == 'false'
        new_file['publish'].should == 'false'
        new_file['preserve'].should == 'false'
        new_file['size'].should == '12345'
      end
    end
    describe 'update_file' do
      before(:all){
        @file={}
        @file[:name]='new_file.jp2'
        @file[:shelve]='false'
        @file[:publish]='false'
        @file[:preserve]='false'
        @file[:size]='12345'
      }
      it 'should modify an existing file record' do
        @item.contentMetadata.update_file(@file,'gw177fc7976_05_0001.jp2')
        xml = @item.contentMetadata.ng_xml
        file=xml.search('//file[@id=\'new_file.jp2\']')
        file.length.should ==1
        file=file.first
        file['shelve'].should == 'false'
        file['publish'].should == 'false'
        file['preserve'].should == 'false'
        file['size'].should == '12345'
      end
      it 'should error out if there isnt an existing record to modify' do
        @item.contentMetadata.update_file(@file,'gw177fc7976_05_0001.jp2').should raise_error
      end
    end
    describe 'rename_file' do
      it 'should update the file id' do
        @item.contentMetadata.rename_file('gw177fc7976_05_0001.jp2','test.jp2')
        xml = @item.contentMetadata.ng_xml
        file=xml.search('//file[@id=\'test.jp2\']')
        file.length.should ==1
      end
    end
    describe 'move_resource' do
      it 'should renumber the resources correctly' do
        file={}
        file[:name]='new_file.jp2'
        file[:shelve]='false'
        file[:publish]='false'
        file[:preserve]='false'
        @files=Array.new
        @files[0]=file
        @item.contentMetadata.add_resource(@files,'resource',1)
        @item.contentMetadata.move_resource('0001','2')
      end
    end
  end
end