require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../foxml_helper')
require 'dor/services/relationship_service'


describe Dor::RelationshipService do

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

  describe 'add_collection' do
    it 'should add a collection' do 
      Dor::RelationshipService.add_collection('druid:oo201oo0001', 'druid:oo201oo0002')
			rels_ext_ds=@obj.datastreams['RELS-EXT']
			@obj.find_relationship_by_name('collection').first.should == 'info:fedora/druid:oo201oo0002'
    end
	end
	describe 'remove_collection' do
		it 'should delete a collection' do
			Dor::RelationshipService.add_collection('druid:oo201oo0001', 'druid:oo201oo0002')
			rels_ext_ds=@obj.datastreams['RELS-EXT']
			@obj.find_relationship_by_name('collection').first.should == 'info:fedora/druid:oo201oo0002'
			Dor::RelationshipService.remove_collection('druid:oo201oo0001', 'druid:oo201oo0002')
		end
	end
end
