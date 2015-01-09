require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../lib/dor/models/contentable')
require 'net/sftp'


class ContentableItem < ActiveFedora::Base
  include Dor::Contentable
end

class SpecNode
  include ActiveFedora::SemanticNode

  attr_accessor :pid
  def initialize (params={})
    self.pid = params[:pid]
  end
  def internal_uri
    'info:fedora/' + pid.to_s
  end
end

describe Dor::Contentable do

  before(:each) { stub_config
                Dor.configure do
                    content do
                      content_user 'user'
                      content_base_dir '/workspace/'
                      content_server 'server'
                    end
                  end
                }
  after(:each)  { unstub_config }

  before(:each) do
    @item = instantiate_fixture('druid:ab123cd4567', Dor::Item)
    @item.contentMetadata.content='<?xml version="1.0"?>
    <contentMetadata objectId="druid:gw177fc7976" type="map">
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
    Dor::Item.stub(:find).and_return(@item)
    file_path=File.dirname(__FILE__) + '/../fixtures/ab123cd4567_descMetadata.xml'
    DruidTools::Druid.any_instance.stub(:path).and_return('file_path/ab123cd4567/ab123cd4567_descMetadata.xml')
    @sftp=double(Net::SFTP)
    @resp=double(Net::SFTP::Response)
    @resp.stub(:code).and_return(123)
    @resp.stub(:message).and_return('sup')
    @sftp.stub(:stat!) do |arg|
      #raise an exception when checking whether the file exists, but no exception when checking whether the folder it belongs in exists
      if not arg=~ /desc/
        #do nothing
      else
        raise(Net::SFTP::StatusException.new @resp, 'sup')
      end
    end
    @sftp.stub(:upload!).and_return(true)
    Net::SFTP.stub(:start).and_return(@sftp) #mock sftp obj
    @file=File.new(File.expand_path(file_path))
  end
  describe 'add_file' do
    it 'should generate the md5, find the size, attempt to sftp, and call the metadata update' do
      @item.add_file(@file,'0001','ab123cd4567_descMetadata.xml')
      xml=@item.contentMetadata.ng_xml
      file_node=xml.search('//file[@id=\'ab123cd4567_descMetadata.xml\']')
      file_node.length.should ==1
      file_node.first()['size'].should == '2472'
      checksums=xml.search('//file[@id=\'ab123cd4567_descMetadata.xml\']/checksum')
      checksums.length.should ==2
      checksums.each do |checksum|
        if checksum['type']=='md5'
          checksum.content.should == '2578947e09ac580f8ac4a11052b7e45c'
        else
          checksum.content.should == '2a2d074945f7bd2c8bcd373b0ca5d1d38837003b'
        end
      end
    end
    it 'should raise an exception if the resource doesnt exist' do
      lambda{@item.add_file(@file,'abc0001','ab123cd4567_descMetadata.xml')}.should raise_error
    end

    it 'should work ok if the object was set up using the old directory structure' do
      @sftp.stub(:stat!) do |arg|
        if not arg=~ /desc/ and not arg=~/ab123/
          #do nothing
        else
          raise(Net::SFTP::StatusException.new @resp, 'sup')
        end
      end
      @item.add_file(@file,'0001','ab123cd4567_descMetadata.xml')
      xml=@item.contentMetadata.ng_xml
      file_node=xml.search('//file[@id=\'ab123cd4567_descMetadata.xml\']')
      file_node.length.should ==1
      file_node.first()['size'].should == '2472'
      checksums=xml.search('//file[@id=\'ab123cd4567_descMetadata.xml\']/checksum')
      checksums.length.should ==2
      checksums.each do |checksum|
        if checksum['type']=='md5'
          checksum.content.should == '2578947e09ac580f8ac4a11052b7e45c'
        else
          checksum.content.should == '2a2d074945f7bd2c8bcd373b0ca5d1d38837003b'
        end
      end
    end
  end

  describe 'replace_file' do
    it 'should update the md5, sha1, and size for the file, and attempt to ftp it to the workspace' do
      @item.replace_file(@file,'gw177fc7976_00_0001.tif')
      xml=@item.contentMetadata.ng_xml
      file_node=xml.search('//file[@id=\'gw177fc7976_00_0001.tif\']')
      file_node.length.should ==1
      file_node=file_node.first
      checksums=xml.search('//file[@id=\'gw177fc7976_00_0001.tif\']/checksum')
      checksums.length.should ==2
      checksums.each do |checksum|
        if checksum['type']=='md5'
          checksum.content.should == '2578947e09ac580f8ac4a11052b7e45c'
        else
          checksum.content.should == '2a2d074945f7bd2c8bcd373b0ca5d1d38837003b'
        end
      end
    end
    it 'should raise an exception if there isnt a matching file record in the metadata' do
      lambda{ @item.replace_file(@file,'abcdgw177fc7976_00_0001.tif')}.should raise_error
    end
  end
  describe 'get_file' do
    it 'should fetch the file' do
      data_file=File.new(File.dirname(__FILE__) + '/../fixtures/ab123cd4567_descMetadata.xml')
      @sftp.stub(:download!).and_return(data_file.read)
      data=@item.get_file('ab123cd4567_descMetadata.xml')
      md5=Digest::MD5.hexdigest(data).should == '2578947e09ac580f8ac4a11052b7e45c'
    end
  end
  describe 'rename_file' do
    it 'should attempt to rename the file in the workspace and update the metadata' do
      @sftp.stub(:rename!)
      @item.rename_file('gw177fc7976_05_0001.jp2','test.jp2')
    end
  end
  describe 'remove_file' do
    it 'should use sftp to remove the file and update the metadata' do
      @sftp.stub(:remove!)
      @item.remove_file('gw177fc7976_05_0001.jp2')
    end
  end

  describe "#decomission" do

    let(:dummy_obj) {
      node = SpecNode.new
      node.stub(:rels_ext).and_return(double("rels_ext", :content_will_change! => true, :content=>''))
      node.pid = 'old:apo'
      node
    }

    let(:obj) do
      o = Dor::Item.new
      o.add_relationship :is_member_of, dummy_obj
      o.add_relationship :is_governed_by, dummy_obj
      o.decomission " test "
      o
    end

    let(:graveyard_apo) do
      node = SpecNode.new
      node.stub(:rels_ext).and_return(double("rels_ext", :content_will_change! => true, :content=>''))
      node.pid = 'new:apo'
      node
    end

    before(:each) do
      Dor::SearchService.stub(:sdr_graveyard_apo_druid)
      ActiveFedora::Base.stub(:find) { graveyard_apo }
    end

    it "removes existing isMemberOf and isGovernedBy relationships" do
      expect(obj.relationships(:is_member_of_collection)).to be_empty
      expect(obj.relationships(:is_member_of)).to be_empty
      expect(obj.relationships(:is_governed_by)).to_not include('info:fedora/old:apo')
    end

    it "adds an isGovernedBy relationship to the SDR graveyard APO" do
      expect(obj.relationships(:is_governed_by)).to eq(["info:fedora/new:apo"])
    end

    it "clears out rightsMetadata and contentMetadata" do
      expect(obj.rightsMetadata.content).to eq('<rightsMetadata/>')
      expect(obj.contentMetadata.content).to eq('<contentMetadata/>')
    end

    it "adds a 'Decommissioned: tag" do
      # make sure the tag is present in its normalized form
      expect(obj.identityMetadata.tags).to include('Decommissioned : test')
    end
  end
end
