require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class GovernableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
  include Dor::Governable
end

describe Dor::Governable do

  before(:each) { stub_config   }
  after(:each)  { unstub_config }

  let(:mock_collection) {
    coll = Dor::Collection.new
    coll.stub(:new? => false, :new_record? => false, :pid => 'druid:oo201oo0002')
    coll.stub(:save)
    coll
  }

  before :each do
    @item = instantiate_fixture("druid:oo201oo0001", Dor::AdminPolicyObject)
   # @item.stub(:new_record? => false)
    Dor::Collection.stub(:find).with("druid:oo201oo0002").and_return(mock_collection)
  end
  describe 'set_read_rights' do
    it 'should raise an exception if the rights option doesnt match the accepted values' do
      lambda{@item.set_read_rights('"druid:oo201oo0001"','Something')}.should raise_error
    end
    it 'should segfault' do
      doc=Nokogiri::XML('<oai_dc:dc xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:srw_dc="info:srw/schema/1/dc-schema" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
        <dc:identifier>druid:ab123cd4567</dc:identifier>
      </oai_dc:dc>')
      node=doc.xpath('//element').first
      new_node=doc.root.clone
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
    it 'should correctly set a dark item to world' do
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
      @item.set_read_rights('world')
      @item.rightsMetadata.ng_xml.should be_equivalent_to <<-XML
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
      <world/>
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
      xml=Nokogiri::XML(rels_ext_ds.to_rels_ext.to_s)
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
			@item.collection_ids.should include('druid:oo201oo0002')
    end
    end

	describe 'remove_collection' do
		it 'should delete a collection' do
			@item.add_collection('druid:oo201oo0002')
			rels_ext_ds=@item.datastreams['RELS-EXT']
      @item.collection_ids.should include('druid:oo201oo0002')
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
  describe 'reapplyAdminPolicyObjectDefaults' do
    it 'should update rightsMetadata from the APO defaultObjectRights' do
      @item.rightsMetadata.ng_xml.search('//rightsMetadata/access[@type=\'read\']/machine/group').length.should == 1
      @apo = instantiate_fixture("druid_zt570tx3016", Dor::AdminPolicyObject)
      @item.should_receive(:admin_policy_object).and_return(@apo)
      @item.reapplyAdminPolicyObjectDefaults
      @item.rightsMetadata.ng_xml.search('//rightsMetadata/access[@type=\'read\']/machine/group').length.should == 0
      @item.rightsMetadata.ng_xml.search('//rightsMetadata/access[@type=\'read\']/machine/world').length.should == 1
    end
  end
end
