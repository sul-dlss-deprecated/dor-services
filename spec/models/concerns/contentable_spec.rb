# frozen_string_literal: true

require 'spec_helper'
require 'net/sftp'

class ContentableItem < ActiveFedora::Base
  include Dor::Contentable
end

class SpecNode
  include ActiveFedora::SemanticNode

  attr_accessor :pid
  def initialize(params = {})
    self.pid = params[:pid]
  end

  def internal_uri
    'info:fedora/' + pid.to_s
  end
end

describe Dor::Contentable do
  before do
    stub_config
    Dor.configure do
      content do
        content_user 'user'
        content_base_dir '/workspace/'
        content_server 'server'
      end
    end
  end

  after  { unstub_config }

  before do
    @item = instantiate_fixture('druid:ab123cd4567', Dor::Item)
    @item.contentMetadata.content = '<?xml version="1.0"?>
    <contentMetadata objectId="druid:ab123cd4567" type="map">
    <resource id="0001" sequence="1" type="image">
    <file format="JPEG2000" id="ab123cd4567_05_0001.jp2" mimetype="image/jp2" preserve="yes" publish="yes" shelve="yes" size="5143883">
    <imageData height="4580" width="5939"/>
    <checksum type="md5">3d3ff46d98f3d517d0bf086571e05c18</checksum>
    <checksum type="sha1">ca1eb0edd09a21f9dd9e3a89abc790daf4d04916</checksum>
    </file>
    <file format="TIFF" id="ab123cd4567_00_0001.tif" mimetype="image/tiff" preserve="yes" publish="no" shelve="no" size="81630420">
    <imageData height="4580" width="5939"/>
    <checksum type="md5">81ccd17bccf349581b779615e82a0366</checksum>
    <checksum type="sha1">12586b624540031bfa3d153299160c4885c3508c</checksum>
    </file>
    </resource>
    </contentMetadata>'
    allow(Dor).to receive(:find).and_return(@item)
    file_path = File.join(fixture_dir, 'ab123cd4567_descMetadata.xml')
    # allow_any_instance_of(DruidTools::Druid).to receive(:path).and_return("#{file_path}/ab123cd4567/ab123cd4567_descMetadata.xml")
    @sftp = double(Net::SFTP)
    @resp = double(Net::SFTP::Response)
    allow(@resp).to receive(:code).and_return(123)
    allow(@resp).to receive(:message).and_return('sup')
    allow(@sftp).to receive(:stat!) do |arg|
      # raise an exception when checking whether the file exists, but no exception when checking whether the folder it belongs in exists
      raise(Net::SFTP::StatusException.new(@resp, 'sup')) if arg =~ /desc/
    end
    allow(@sftp).to receive(:upload!).and_return(true)
    allow(Net::SFTP).to receive(:start).and_return(@sftp) # mock sftp obj
    @file = File.new(File.expand_path(file_path))
  end

  describe 'add_file' do
    before do
      expect(Deprecation).to receive(:warn)
    end

    it 'generates the md5, find the size, attempt to sftp, and call the metadata update' do
      @item.add_file(@file, '0001', 'ab123cd4567_descMetadata.xml')
      xml = @item.contentMetadata.ng_xml
      file_node = xml.search('//file[@id=\'ab123cd4567_descMetadata.xml\']')
      expect(file_node.length).to eq(1)
      expect(file_node.first['size']).to eq('2502')
      checksums = xml.search('//file[@id=\'ab123cd4567_descMetadata.xml\']/checksum')
      expect(checksums.length).to eq(2)
      checksums.each do |checksum|
        if checksum['type'] == 'md5'
          expect(checksum.content).to eq('55251c7b93b3fbab83354f28e267f42f')
        else
          expect(checksum.content).to eq('5337616261fce62ed594df2d6dbc79ffbe136fb5')
        end
      end
    end
    it 'raises an exception if the resource doesnt exist' do
      expect{ @item.add_file(@file, 'abc0001', 'ab123cd4567_descMetadata.xml') }.to raise_error(RuntimeError)
    end

    it 'works ok if the object was set up using the old directory structure' do
      allow(@sftp).to receive(:stat!) do |arg|
        raise(Net::SFTP::StatusException.new(@resp, 'sup')) if arg =~ /desc/ || arg =~ /ab123/
      end
      @item.add_file(@file, '0001', 'ab123cd4567_descMetadata.xml')
      xml = @item.contentMetadata.ng_xml
      file_node = xml.search('//file[@id=\'ab123cd4567_descMetadata.xml\']')
      expect(file_node.length).to eq(1)
      expect(file_node.first['size']).to eq('2502')
      checksums = xml.search('//file[@id=\'ab123cd4567_descMetadata.xml\']/checksum')
      expect(checksums.length).to eq(2)
      checksums.each do |checksum|
        if checksum['type'] == 'md5'
          expect(checksum.content).to eq('55251c7b93b3fbab83354f28e267f42f')
        else
          expect(checksum.content).to eq('5337616261fce62ed594df2d6dbc79ffbe136fb5')
        end
      end
    end
  end

  describe 'replace_file' do
    before do
      expect(Deprecation).to receive(:warn)
    end

    it 'updates the md5, sha1, and size for the file, and attempt to ftp it to the workspace' do
      @item.replace_file(@file, 'ab123cd4567_00_0001.tif')
      xml = @item.contentMetadata.ng_xml
      file_node = xml.search('//file[@id=\'ab123cd4567_00_0001.tif\']')
      expect(file_node.length).to eq(1)
      checksums = xml.search('//file[@id=\'ab123cd4567_00_0001.tif\']/checksum')
      expect(checksums.length).to eq(2)
      checksums.each do |checksum|
        if checksum['type'] == 'md5'
          expect(checksum.content).to eq('55251c7b93b3fbab83354f28e267f42f')
        else
          expect(checksum.content).to eq('5337616261fce62ed594df2d6dbc79ffbe136fb5')
        end
      end
    end

    it 'raises an exception if there isnt a matching file record in the metadata' do
      expect{ @item.replace_file(@file, 'abcdab123cd4567_00_0001.tif') }.to raise_error(StandardError)
    end
  end

  describe 'get_preserved_file' do
    let(:filename) { 'old_file' }
    let(:item_version) { 2 }
    let(:preserved_file_content) { 'expected content' }

    it 'gets the file content' do
      expect(Sdr::Client).to receive(:get_preserved_file_content).with(@item.id, filename, item_version).and_return(preserved_file_content)
      expect(Deprecation).to receive(:warn)
      returned_content = @item.get_preserved_file(filename, item_version)
      expect(returned_content).to eq(preserved_file_content)
    end
  end

  describe 'get_file' do
    it 'fetches the file' do
      data_file = File.new(File.join(fixture_dir, 'ab123cd4567_descMetadata.xml'))
      expect(@sftp).to receive(:download!).and_return(data_file.read)
      expect(Deprecation).to receive(:warn)
      data = @item.get_file('ab123cd4567_descMetadata.xml')
      expect(Digest::MD5.hexdigest(data)).to eq('55251c7b93b3fbab83354f28e267f42f')
    end
  end

  describe 'rename_file' do
    before do
      expect(Deprecation).to receive(:warn)
    end

    it 'attempts to rename the file in the workspace and update the metadata' do
      expect(@sftp).to receive(:rename!)
      @item.rename_file('ab123cd4567_05_0001.jp2', 'test.jp2')
    end
  end

  describe 'remove_file' do
    before do
      expect(Deprecation).to receive(:warn)
    end

    it 'uses sftp to remove the file and update the metadata' do
      expect(@sftp).to receive(:remove!)
      @item.remove_file('ab123cd4567_05_0001.jp2')
    end
  end

  describe 'is_file_in_workspace?' do
    before do
      expect(Deprecation).to receive(:warn)
      @mock_filename = 'fake_file'
      @mock_druid_obj = double(DruidTools::Druid)
      expect(DruidTools::Druid).to receive(:new).and_return(@mock_druid_obj)
    end

    it 'returns true if the file is in the workspace for the object' do
      expect(@mock_druid_obj).to receive(:find_content).with(@mock_filename).and_return('this is not nil')
      expect(@item).to be_is_file_in_workspace(@mock_filename)
    end
    it 'returns false if the file is not in the workspace for the object' do
      expect(@mock_druid_obj).to receive(:find_content).with(@mock_filename).and_return(nil)
      expect(@item).not_to be_is_file_in_workspace(@mock_filename)
    end
  end

  describe '#decommission' do
    let(:obj) { Dor::Item.new }
    let(:service) { instance_double(Dor::DecommissionService, decommission: true) }

    it 'delgates to DecommissionService' do
      expect(Deprecation).to receive(:warn)
      allow(Dor::DecommissionService).to receive(:new).with(obj).and_return(service)
      obj.decommission(' test ')
      expect(service).to have_received(:decommission).with(' test ')
    end
  end

  describe '#add_constituent' do
    let(:obj) { Dor::Item.new }

    let(:child_obj) do
      node = SpecNode.new
      allow(node).to receive(:rels_ext).and_return(double('rels_ext', content_will_change!: true, content: ''))
      node.pid = 'druid:aa111bb2222'
      node
    end

    before do
      expect(Deprecation).to receive(:warn)
      allow(ActiveFedora::Base).to receive(:find) { child_obj }
    end

    it 'adds an isConstituentOf relationship from the object to the parent druid' do
      obj.add_constituent('druid:aa111bb2222')
      expect(obj.relationships(:is_constituent_of)).to eq(['info:fedora/druid:aa111bb2222'])
    end
  end
end
