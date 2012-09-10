require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../foxml_helper')
require 'dor/services/rights_metadata_service'


describe Dor::RightsMetadataService do

before :all do
  stub_config
end

after :all do
  unstub_config
end

before :each do
  @pid = 'druid:oo201oo0001'
  
  Dor::SuriService.stub!(:mint_id).and_return("druid:ab123cd4567")
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
describe 'set_read_rights' do
  it 'should raise an exception if the rights option doesnt match the accepted values' do
    lambda{Dor::RightsMetadataService.set_read_rights('"druid:oo201oo0001"','Something')}.should raise_error
  end
  it 'should raise an exception if the rights metadata stream is empty' do
    @obj.datastreams['rightsMetadata'].ng_xml=''
    lambda{Dor::RightsMetadataService.set_read_rights('"druid:oo201oo0001"','World')}.should raise_error
  end
  it 'should cahnge the read permissions value from <group>stanford</group> to <none/> ' do

    
    @obj.datastreams['rightsMetadata'].ng_xml.should be_equivalent_to <<-XML
    <?xml version="1.0"?>
    <rightsMetadata>
              <copyright>
                <human type="copyright">This work is in the Public Domain.</human>
              </copyright>
              <access type="discover">
                <machine>
                  <world/>
                </machine>
              </access>
              <access type="read">
                <machine>
                <group>Stanford</group>
                </machine>
              </access>
              <use>
                <human type="creativecommons">Attribution Share Alike license</human>
                <machine type="creativecommons">by-sa</machine>
              </use>
            </rightsMetadata>
    XML
    #this should work because the find call inside set_read_rights is stubbed to return @obj, so the modifications happen to that, not a fresh instance
    Dor::RightsMetadataService.set_read_rights('druid:oo201oo0001','none')
    @obj.datastreams['rightsMetadata'].ng_xml.should be_equivalent_to <<-XML
    <?xml version="1.0"?>
    <rightsMetadata>
              <copyright>
                <human type="copyright">This work is in the Public Domain.</human>
              </copyright>
              <access type="discover">
                <machine>
                  <world/>
                </machine>
              </access>
              <access type="read">
                <machine>
                <none/>
                </machine>
              </access>
              <use>
                <human type="creativecommons">Attribution Share Alike license</human>
                <machine type="creativecommons">by-sa</machine>
              </use>
            </rightsMetadata>
    XML
  end
  it 'should ' do
    
  end
end
end