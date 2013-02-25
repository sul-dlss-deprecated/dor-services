require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class GovernableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
  include Dor::Governable
end

describe Dor::Governable do

  before(:each) { stub_config   }
  after(:each)  { unstub_config }

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
    it 'should set an item to dark, removing the discovery rights' do
      @item.set_read_rights('dark')
      @item.rightsMetadata.ng_xml.should be_equivalent_to <<-XML
      <?xml version="1.0"?>
      <rightsMetadata>
      <copyright>
      <human type="copyright">This work is in the Public Domain.</human>
      </copyright>
      <access type="discover">
      <machine>
      <none/>
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
    it 'should cahnge the read permissions value from <group>stanford</group> to <none/> ' do    
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
      rels_ext_ds.serialize!
      xml=Nokogiri::XML(rels_ext_ds.content.to_s)
      xml.should be_equivalent_to <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
             <rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#">
               <rdf:Description rdf:about="info:fedora/druid:oo201oo0001">
                 <hydra:isGovernedBy rdf:resource="info:fedora/druid:fg890hi1234"/>
                 <fedora-model:hasModel rdf:resource="info:fedora/afmodel:Hydrus_Item"/>
                 <fedora:isMemberOf rdf:resource="info:fedora/druid:oo201oo0002"/>
                 <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:oo201oo0002"/>
               </rdf:Description>
             </rdf:RDF>
      XML
    end
  end

  describe 'remove_collection' do
    it 'should delete a collection' do
      @item.add_collection('druid:oo201oo0002')
      rels_ext_ds=@item.datastreams['RELS-EXT']
      @item.remove_collection('druid:oo201oo0002')
      rels_ext_ds.serialize!
      xml=Nokogiri::XML(rels_ext_ds.content.to_s)
      xml.should be_equivalent_to <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
             <rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#">
               <rdf:Description rdf:about="info:fedora/druid:oo201oo0001">
                 <hydra:isGovernedBy rdf:resource="info:fedora/druid:fg890hi1234"/>
                 <fedora-model:hasModel rdf:resource="info:fedora/afmodel:Hydrus_Item"/>
               </rdf:Description>
             </rdf:RDF>
      XML
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

  describe "initiate_apo_workflow" do
    it "calls Processable.initialize_workflow without creating a datastream when the object is new" do
      i = GovernableItem.new
      i.should_receive(:initialize_workflow).with('accessionWF', 'dor', false)
      i.initiate_apo_workflow('accessionWF')
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

	describe "initiate_apo_workflow" do
	  it "calls Processable.initialize_workflow without creating a datastream when the object is new" do
	    i = GovernableItem.new
	    i.should_receive(:initialize_workflow).with('accessionWF', 'dor', false)
	    i.initiate_apo_workflow('accessionWF')
	  end
	end
	describe 'can_manage_item?' do
	  it 'should match a group that has rights' do
      @item.can_manage_item?(['dor-administrator']).should == true
    end
    it 'shouldnt match a group that doesnt have rights' do
      @item.can_manage_item?(['dor-apo-metadata']).should == false
    end
  end
  describe 'can_manage_desc_metadata?' do
    it 'should match a group that has rights' do
      @item.can_manage_desc_metadata?(['dor-apo-metadata']).should == true
    end
    it 'shouldnt match a group that doesnt have rights' do
      @item.can_manage_desc_metadata?(['dor-viewers']).should == false
    end
  end
  describe 'can_manage_content?' do
    it 'should match a group that has rights' do
      @item.can_manage_content?(['dor-administrator']).should == true
    end
    it 'shouldnt match a group that doesnt have rights' do
      @item.can_manage_content?(['dor-apo-metadata']).should == false
    end
  end
  describe 'can_manage_rights?' do
    it 'should match a group that has rights' do
      @item.can_manage_rights?(['dor-administrator']).should == true
    end
    it 'shouldnt match a group that doesnt have rights' do
      @item.can_manage_rights?(['dor-apo-metadata']).should == false
    end
  end
  describe 'can_manage_embargo?' do
    it 'should match a group that has rights' do
      @item.can_manage_embargo?(['dor-administrator']).should == true
    end
    it 'shouldnt match a group that doesnt have rights' do
      @item.can_manage_embargo?(['dor-apo-metadata']).should == false
    end
  end
  describe 'can_view_content?' do
    it 'should match a group that has rights' do
      @item.can_view_content?(['dor-viewer']).should == true
    end
    it 'shouldnt match a group that doesnt have rights' do
      @item.can_view_content?(['dor-people']).should == false
    end
  end
  describe 'can_view_metadata?' do
    it 'should match a group that has rights' do
      @item.can_view_metadata?(['dor-viewer']).should == true
    end
    it 'shouldnt match a group that doesnt have rights' do
      @item.can_view_metadata?(['dor-people']).should == false
    end
  end
end
