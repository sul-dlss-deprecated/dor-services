require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class GovernableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
  include Dor::Governable
end

describe Dor::Governable do

  before(:all) { stub_config   }
  after(:all)  { unstub_config }

  before :each do
    @item = instantiate_fixture("druid:oo201oo0001", Dor::AdminPolicyObject)
  end
describe 'set_read_rights' do
  it 'should raise an exception if the rights option doesnt match the accepted values' do
    lambda{@item.set_read_rights('"druid:oo201oo0001"','Something')}.should raise_error
  end
  it 'should raise an exception if the rights metadata stream is empty' do
    @item.datastreams['rightsMetadata'].ng_xml=''
    lambda{@item.set_read_rights('World')}.should raise_error
  end
  it 'should cahnge the read permissions value from <group>stanford</group> to <none/> ' do    
    @item.datastreams['rightsMetadata'].ng_xml.should be_equivalent_to <<-XML
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
    @item.set_read_rights('none')
    @item.datastreams['rightsMetadata'].ng_xml.should be_equivalent_to <<-XML
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
  end
  describe 'add_collection' do
it 'should add a collection' do 
      @item.add_collection('druid:oo201oo0002')
			rels_ext_ds=@item.datastreams['RELS-EXT']
			@item.find_relationship_by_name('collection').first.should == 'info:fedora/druid:oo201oo0002'
    end
    end
	
	describe 'remove_collection' do
		it 'should delete a collection' do
			@item.add_collection('druid:oo201oo0002')
			rels_ext_ds=@item.datastreams['RELS-EXT']
			@item.find_relationship_by_name('collection').first.should == 'info:fedora/druid:oo201oo0002'
			@item.remove_collection('druid:oo201oo0002')
		end
	end

end