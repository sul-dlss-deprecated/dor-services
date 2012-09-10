require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../foxml_helper')
require 'dor/services/identity_metadata_service'


describe Dor::IdentityMetadataService do

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

  describe 'update_source_id' do
    it 'should set the source_id if one doesnt exist' do 
      @obj.identityMetadata.sourceId.should == nil
      Dor::IdentityMetadataService.update_source_id('druid:oo201oo0001', 'fake:sourceid')
      @obj.identityMetadata.sourceId.should == 'fake:sourceid'
    end
    it 'should replace the source_id if one exists' do 

      Dor::IdentityMetadataService.update_source_id('druid:oo201oo0001', 'fake:sourceid')
      @obj.identityMetadata.sourceId.should == 'fake:sourceid'
      Dor::IdentityMetadataService.update_source_id('druid:oo201oo0001', 'new:sourceid2')
      @obj.identityMetadata.sourceId.should == 'new:sourceid2'
    end
  end
  
  describe 'add_other_Id' do
    it 'should add an other_id record' do
      Dor::IdentityMetadataService.add_other_Id('druid:oo201oo0001', 'mdtoolkit:someid123')
      @obj.identityMetadata.otherId('mdtoolkit').first.should == 'someid123'
    end
    it 'should raise an exception if a record of that type already exists' do
      Dor::IdentityMetadataService.add_other_Id('druid:oo201oo0001', 'mdtoolkit:someid123')
      @obj.identityMetadata.otherId('mdtoolkit').first.should == 'someid123'
      lambda{Dor::IdentityMetadataService.add_other_Id('druid:oo201oo0001', 'mdtoolkit:someid123')}.should raise_error
    end
  end
  
  describe 'update_other_Id' do
    it 'should update an existing id and return true to indicate that it found something to update' do
      Dor::IdentityMetadataService.add_other_Id('druid:oo201oo0001', 'mdtoolkit:someid123')
      @obj.identityMetadata.otherId('mdtoolkit').first.should == 'someid123'
      #return value should be true when it finds something to update
      Dor::IdentityMetadataService.update_other_Id('druid:oo201oo0001', 'mdtoolkit:someotherid234').should == true
      @obj.identityMetadata.otherId('mdtoolkit').first.should == 'someotherid234'
    end
    it 'should return false if there was no existing record to update' do
      Dor::IdentityMetadataService.update_other_Id('druid:oo201oo0001', 'mdtoolkit:someotherid234').should == false
    end
  end
  
  describe 'remove_other_Id' do
    it 'should remove an existing otherid when the tag and value match' do
      Dor::IdentityMetadataService.add_other_Id('druid:oo201oo0001', 'mdtoolkit:someid123')
      @obj.identityMetadata.otherId('mdtoolkit').first.should == 'someid123'
      Dor::IdentityMetadataService.remove_other_Id('druid:oo201oo0001', 'mdtoolkit:someid123').should == true
      @obj.identityMetadata.otherId('mdtoolkit').length.should == 0
      @obj.identityMetadata.dirty?.should == true
    end
    it 'should return false if there was nothing to delete' do
      Dor::IdentityMetadataService.remove_other_Id('druid:oo201oo0001', 'mdtoolkit:someid123').should == false
      @obj.identityMetadata.dirty?.should == false
    end
  end
  
  describe 'add_tag' do
    it 'should add a new tag' do
      Dor::IdentityMetadataService.add_tag('druid:oo201oo0001', 'sometag:someval')
      @obj.identityMetadata.tags().include?('sometag:someval').should == true
      @obj.identityMetadata.dirty?.should == true
    end
    it 'should raise an exception if there is an existing tag like it' do
      Dor::IdentityMetadataService.add_tag('druid:oo201oo0001', 'sometag:someval')
      @obj.identityMetadata.tags().include?('sometag:someval').should == true
      lambda {Dor::IdentityMetadataService.add_tag('druid:oo201oo0001', 'sometag:someval')}.should raise_error
    end
  end
  describe 'update_tag' do
    it 'should update a tag' do
      Dor::IdentityMetadataService.add_tag('druid:oo201oo0001', 'sometag:someval')
      @obj.identityMetadata.tags().include?('sometag:someval').should == true
      Dor::IdentityMetadataService.update_tag('druid:oo201oo0001', 'sometag:someval','new:tag').should == true
      @obj.identityMetadata.tags().include?('sometag:someval').should == false
      @obj.identityMetadata.tags().include?('new:tag').should == true
      @obj.identityMetadata.dirty?.should == true
    end
    it 'should return false if there is no matching tag to update' do
      Dor::IdentityMetadataService.update_tag('druid:oo201oo0001', 'sometag:someval','new:tag').should == false
      @obj.identityMetadata.dirty?.should == false
    end
  end
  describe 'delete_tag' do
    it 'should delete a tag' do
    Dor::IdentityMetadataService.add_tag('druid:oo201oo0001', 'sometag:someval')
    @obj.identityMetadata.tags().include?('sometag:someval').should == true
    Dor::IdentityMetadataService.remove_tag('druid:oo201oo0001', 'sometag:someval').should == true
    @obj.identityMetadata.tags().include?('sometag:someval').should == false
    @obj.identityMetadata.dirty?.should == true
    end
  end
end












