require 'spec_helper'

class GovernableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
  include Dor::Governable
end

describe Dor::Governable do

  before(:each) { stub_config   }
  after(:each)  { unstub_config }

  before :each do
    @item = instantiate_fixture('druid:oo201oo0001', Dor::AdminPolicyObject)
    # @item.stub(:new_record? => false)
    allow(Dor::Collection).to receive(:find).with('druid:oo201oo0002').and_return(mock_collection)
  end

  let(:mock_collection) {
    coll = Dor::Collection.new
    allow(coll).to receive(:new?).and_return false
    allow(coll).to receive(:new_record?).and_return false
    allow(coll).to receive(:pid).and_return 'druid:oo201oo0002'
    allow(coll).to receive(:save)
    coll
  }

  describe 'set_read_rights error handling' do
    it 'should raise an exception if the rights option does not match the accepted values' do
      expect{@item.set_read_rights('"druid:oo201oo0001"', 'Something')}.to raise_error(ArgumentError)
    end
    it 'should raise an exception if the rights option does not match the accepted values' do
      expect{@item.set_read_rights('mambo')}.to raise_error(ArgumentError)
    end
  end

  describe 'rights' do
    it 'returns "Stanford" for the "stanford" rights' do
      @item.set_read_rights('stanford')
      expect(@item.rights).to eq('Stanford')
    end
    it 'returns "World" for the "world" rights' do
      @item.set_read_rights('world')
      expect(@item.rights).to eq('World')
    end
    it 'returns "Dark" for the "dark" rights' do
      @item.set_read_rights('dark')
      expect(@item.rights).to eq('Dark')
    end
    it 'returns "None" for the "none" rights' do
      @item.set_read_rights('none')
      expect(@item.rights).to eq('None')
    end
  end

  describe 'set_read_rights' do
    it 'should set rights to dark (double none), removing the discovery rights' do
      @item.set_read_rights('dark')
      expect(@item.rightsMetadata.ng_xml).to be_equivalent_to <<-XML
      <?xml version="1.0"?>
      <rightsMetadata>
        <copyright>
          <human type="copyright">This work is in the Public Domain.</human>
        </copyright>
        <access type="discover">
          <machine><none/></machine>
        </access>
        <access type="read">
          <machine><none/></machine>
        </access>
        <use>
          <human type="creativecommons">Attribution Share Alike license</human>
          <machine type="creativecommons">by-sa</machine>
        </use>
      </rightsMetadata>
      XML
    end
    it 'should set rights to <world/>' do
      @item.set_read_rights('world')
      expect(@item.rightsMetadata.ng_xml).to be_equivalent_to <<-XML
      <?xml version="1.0"?>
      <rightsMetadata>
        <copyright>
          <human type="copyright">This work is in the Public Domain.</human>
        </copyright>
        <access type="discover">
          <machine><world/></machine>
        </access>
        <access type="read">
          <machine><world/></machine>
        </access>
        <use>
          <human type="creativecommons">Attribution Share Alike license</human>
          <machine type="creativecommons">by-sa</machine>
        </use>
      </rightsMetadata>
      XML
    end
    it 'should set rights to stanford' do
      @item.set_read_rights('stanford')
      expect(@item.rightsMetadata.ng_xml).to be_equivalent_to <<-XML
      <?xml version="1.0"?>
      <rightsMetadata>
        <copyright>
          <human type="copyright">This work is in the Public Domain.</human>
        </copyright>
        <access type="discover">
          <machine><world/></machine>
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
    end
    it 'should set rights to <none/>' do
      # this should work because the find call inside set_read_rights is stubbed to return @obj, so the modifications happen to that, not a fresh instance
      @item.set_read_rights('none')
      expect(@item.datastreams['rightsMetadata'].ng_xml).to be_equivalent_to <<-XML
      <?xml version="1.0"?>
      <rightsMetadata>
        <copyright>
          <human type="copyright">This work is in the Public Domain.</human>
        </copyright>
        <access type="discover">
          <machine><world/></machine>
        </access>
        <access type="read">
          <machine><none/></machine>
        </access>
        <use>
          <human type="creativecommons">Attribution Share Alike license</human>
          <machine type="creativecommons">by-sa</machine>
        </use>
      </rightsMetadata>
      XML
    end
    it 'should change the read permissions value from <group>stanford</group> to <none/>' do
      expect(@item.datastreams['rightsMetadata'].ng_xml).to be_equivalent_to <<-XML
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
      # this should work because the find call inside set_read_rights is stubbed to return @obj, so the modifications happen to that, not a fresh instance
      @item.set_read_rights('none')
      expect(@item.datastreams['rightsMetadata'].ng_xml).to be_equivalent_to <<-XML
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

  describe 'reset_to_apo_default' do
    it 'should set rights to APO rights' do
      apo = instantiate_fixture('druid:fg890hi1234', Dor::AdminPolicyObject)
      apo_rights = apo.rightsMetadata.ng_xml
      allow(@item).to receive(:admin_policy_object).and_return(apo)
      @item.set_read_rights('dark')
      expect(@item.rightsMetadata.ng_xml).not_to be_equivalent_to apo_rights
      @item.reset_to_apo_default
      expect(@item.rightsMetadata.ng_xml).to be_equivalent_to apo_rights
    end
  end

  describe 'to_solr' do
    it 'should include a rights facet' do
      allow(@item).to receive(:milestones).and_return({})
      @item.set_read_rights('world')
      solr_doc = @item.to_solr
      expect(solr_doc).to match a_hash_including('rights_ssim' => ['World'], :id => @item.pid)
    end
    it 'should not error if there is nothing in the datastream' do
      allow(@item).to receive(:milestones).and_return({})
      allow(@item).to receive(:rightsMetadata).and_return(ActiveFedora::OmDatastream.new)
      solr_doc = @item.to_solr
      expect(solr_doc).not_to include('rights_facet')
    end
  end

  describe 'add_collection' do
    def check_collection
      rels_ext_ds = @item.datastreams['RELS-EXT']
      xml = Nokogiri::XML(rels_ext_ds.to_rels_ext.to_s)
      expect(xml).to be_equivalent_to <<-XML
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
    it 'should find and add a collection' do
      expect(Dor::Collection).to receive(:find).once
      @item.add_collection('druid:oo201oo0002')
      check_collection
    end
    it 'should add a collection' do
      expect(Dor::Collection).not_to receive(:find)
      @item.add_collection(mock_collection)
      check_collection
    end
  end

  describe 'remove_collection' do
    def check_collection(rels_ext_ds)
      rels_ext_ds.serialize!
      xml = Nokogiri::XML(rels_ext_ds.content.to_s)
      expect(xml).to be_equivalent_to <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#">
        <rdf:Description rdf:about="info:fedora/druid:oo201oo0001">
          <hydra:isGovernedBy rdf:resource="info:fedora/druid:fg890hi1234"/>
          <fedora-model:hasModel rdf:resource="info:fedora/afmodel:Hydrus_Item"/>
        </rdf:Description>
      </rdf:RDF>
      XML
    end
    it 'should find and delete a collection' do
      expect(Dor::Collection).to receive(:find).twice
      @item.add_collection('druid:oo201oo0002')
      rels_ext_ds = @item.datastreams['RELS-EXT']
      @item.remove_collection('druid:oo201oo0002')
      check_collection(rels_ext_ds)
    end
    it 'should delete a collection' do
      expect(Dor::Collection).not_to receive(:find)
      @item.add_collection(mock_collection)
      rels_ext_ds = @item.datastreams['RELS-EXT']
      @item.remove_collection(mock_collection)
      check_collection(rels_ext_ds)
    end
  end

  describe 'initiate_apo_workflow' do
    it 'calls Processable.initialize_workflow without creating a datastream when the object is new' do
      i = GovernableItem.new
      expect(i).to receive(:initialize_workflow).with('accessionWF', false)
      i.initiate_apo_workflow('accessionWF')
    end
  end

  describe '#default_workflow_lane' do
    before :each do
      @item = instantiate_fixture('druid:ab123cd4567', GovernableItem)
    end
    it "returns the default lane as defined in the object's APO" do
      apo  = instantiate_fixture('druid:fg890hi1234', Dor::AdminPolicyObject)
      allow(@item).to receive(:admin_policy_object) { apo }
      expect(@item.default_workflow_lane).to eq 'fast'
    end
    it "returns the value 'default' if the object does not have an APO" do
      allow(@item).to receive(:admin_policy_object) { nil }
      expect(@item.default_workflow_lane).to eq 'default'
    end
    it "returns the value 'default' if the object's APO does not have a default lane defined" do
      apo  = instantiate_fixture('druid:zt570tx3016', Dor::AdminPolicyObject)
      allow(@item).to receive(:admin_policy_object) { apo }
      expect(@item.default_workflow_lane).to eq 'default'
    end
    it "returns the value 'default' for a newly created object" do
      apo  = instantiate_fixture('druid:zt570tx3016', Dor::AdminPolicyObject)
      item = GovernableItem.new
      item.admin_policy_object = apo
      expect(item.default_workflow_lane).to eq 'default'
    end
  end

  describe 'add_collection' do
    it 'should add a collection' do
      @item.add_collection('druid:oo201oo0002')
      expect(@item.collection_ids).to include('druid:oo201oo0002')
    end
  end

  describe 'remove_collection' do
    it 'should delete a collection' do
      @item.add_collection('druid:oo201oo0002')
      expect(@item.collection_ids).to include('druid:oo201oo0002')
      @item.remove_collection('druid:oo201oo0002')
    end
  end

  describe 'initiate_apo_workflow' do
    it 'calls Processable.initialize_workflow without creating a datastream when the object is new' do
      i = GovernableItem.new
      expect(i).to receive(:initialize_workflow).with('accessionWF', false)
      i.initiate_apo_workflow('accessionWF')
    end
  end

  describe 'reapplyAdminPolicyObjectDefaults' do
    it 'should update rightsMetadata from the APO defaultObjectRights' do
      expect(@item.rightsMetadata.ng_xml.search('//rightsMetadata/access[@type=\'read\']/machine/group').length).to eq(1)
      @apo = instantiate_fixture('druid_zt570tx3016', Dor::AdminPolicyObject)
      expect(@item).to receive(:admin_policy_object).and_return(@apo)
      @item.reapplyAdminPolicyObjectDefaults
      expect(@item.rightsMetadata.ng_xml.search('//rightsMetadata/access[@type=\'read\']/machine/group').length).to eq(0)
      expect(@item.rightsMetadata.ng_xml.search('//rightsMetadata/access[@type=\'read\']/machine/world').length).to eq(1)
    end
  end
end
