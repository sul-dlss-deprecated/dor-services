require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../foxml_helper')
require 'dor/services/descriptive_metadata_service'


describe Dor::DescriptiveMetadataService do

  before :all do
    stub_config
  end

  after :all do
    unstub_config
  end

  before :each do
    @pid = 'druid:oo201oo0001'
    @mock_repo = mock(Rubydora::Repository).as_null_object
    if ActiveFedora::Base.respond_to? :connection_for_pid
      ActiveFedora::Base.stub(:connection_for_pid).and_return(@mock_repo)
    else
      ActiveFedora.stub_chain(:fedora,:connection).and_return(@mock_repo)
    end
    @mock_solr = mock(RSolr::Connection).as_null_object
    Dor::SearchService.stub(:solr).and_return(@mock_solr)
    @obj  = instantiate_fixture("druid:oo201oo0001", Dor::AdminPolicyObject)

    Dor::Item.any_instance.stub(:save).and_return(true)
    Dor::Item.stub(:find).and_return(@obj)
    @params = {
      :object_type => 'item', 
      :content_model => 'googleScannedBook', 
      :admin_policy => 'druid:fg890hi1234', 
      :label => 'Google : Scanned Book 12345', 
      :source_id => { :barcode => 9191919191 }, 
      :other_ids => { :catkey => '000', :uuid => '111' }, 
      :tags => ['Google : Google Tag!','Google : Other Google Tag!']
    }
  end

  describe 'update_title' do
    it 'should update the title' do 
      found=false 
      Dor::DescriptiveMetadataService.update_title('druid:oo201oo0001', 'new title')
      @obj.descMetadata.ng_xml.search('//mods:mods/mods:titleInfo/mods:title', 'mods' => 'http://www.loc.gov/mods/v3').each do |node|
      node.content.should == 'new title'
      found=true
      end
      found.should == true
    end
		it 'should raise an exception if the mods lacks a title' do
			Dor::DescriptiveMetadataService.update_title('druid:oo201oo0001', 'new title')
      @obj.descMetadata.ng_xml.search('//mods:mods/mods:titleInfo/mods:title', 'mods' => 'http://www.loc.gov/mods/v3').each do |node|
				node.remove
			end	
			lambda {Dor::DescriptiveMetadataService.update_title('druid:oo201oo0001', 'new title')}.should raise_error
		end
	end
  describe 'add_identifier' do
    it 'should add an identifier' do
      Dor::DescriptiveMetadataService.add_identifier('druid:oo201oo0001', 'type', 'new attribute')
      res=@obj.descMetadata.ng_xml.search('//mods:identifier','mods' => 'http://www.loc.gov/mods/v3')
      res.length.should > 0
      res.each do |node|
      node.content.should == 'new attribute'
      end
    end
    
  end
	describe 'delete_identifier' do
it 'should delete an identifier' do
		Dor::DescriptiveMetadataService.add_identifier('druid:oo201oo0001', 'type', 'new attribute')
    res=@obj.descMetadata.ng_xml.search('//mods:identifier','mods' => 'http://www.loc.gov/mods/v3')
    res.length.should > 0
    res.each do |node|
			node.content.should == 'new attribute'
    end
		Dor::DescriptiveMetadataService.delete_identifier('druid:oo201oo0001', 'type', 'new attribute').should == true
		res=@obj.descMetadata.ng_xml.search('//mods:identifier','mods' => 'http://www.loc.gov/mods/v3')
    res.length.should == 0 
  end
	it 'should return false if there was nothing to delete' do
	  Dor::DescriptiveMetadataService.delete_identifier('druid:oo201oo0001', 'type', 'new attribute').should == false
	end
end
end
