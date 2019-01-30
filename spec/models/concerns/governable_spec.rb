# frozen_string_literal: true

require 'spec_helper'

class GovernableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
  include Dor::Governable
end

RSpec.describe Dor::Governable do
  before { stub_config }

  after { unstub_config }

  let(:mock_collection) do
    coll = Dor::Collection.new
    allow(coll).to receive(:new?).and_return false
    allow(coll).to receive(:new_record?).and_return false
    allow(coll).to receive(:pid).and_return 'druid:oo201oo0002'
    allow(coll).to receive(:save)
    coll
  end

  before do
    @item = instantiate_fixture('druid:oo201oo0001', Dor::AdminPolicyObject)
    allow(Dor::Collection).to receive(:find).with('druid:oo201oo0002').and_return(mock_collection)
  end

  describe 'set_read_rights error handling' do
    it 'raises an exception if the rights option doesnt match the accepted values' do
      expect{ @item.set_read_rights('"druid:oo201oo0001"', 'Something') }.to raise_error(ArgumentError)
    end
    it 'raises an exception if the rights option doesnt match the accepted values' do
      expect{ @item.set_read_rights('mambo') }.to raise_error(ArgumentError)
    end
  end

  describe 'unshelve_and_unpublish' do
    before do
      @current_item = instantiate_fixture('druid:bb046xn0881', Dor::Item)
    end

    it 'does not do anything if there is no contentMetadata' do
      @current_item = instantiate_fixture('druid:bb004bn8654', Dor::Item)
      expect(@current_item).not_to receive(:ng_xml_will_change!)
      @current_item.unshelve_and_unpublish
    end

    it 'notifies that the XML will change' do
      expect(@current_item.contentMetadata).to receive(:ng_xml_will_change!).once
      @current_item.unshelve_and_unpublish
    end

    it 'sets publish and shelve to no for all files' do
      @current_item.unshelve_and_unpublish
      new_metadata = @current_item.datastreams['contentMetadata']
      expect(new_metadata.ng_xml.xpath('/contentMetadata/resource//file[@publish="yes"]').length).to eq(0)
      expect(new_metadata.ng_xml.xpath('/contentMetadata/resource//file[@shelve="yes"]').length).to eq(0)
    end
  end

  describe 'set_read_rights' do
    it 'sets rights to dark, unshelving and unpublishing content metadata' do
      @current_item = instantiate_fixture('druid:bb046xn0881', Dor::Item)
      allow(Dor).to receive(:find).with(@current_item.pid).and_return(@current_item)

      expect(@current_item).to receive(:unshelve_and_unpublish)
      @current_item.set_read_rights('dark')
    end

    it 'sets rights to dark (double none), removing the discovery rights' do
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
    it 'sets rights to <world/> and not change publish or shelve attributes' do
      @item.set_read_rights('world')
      expect(@item).not_to receive(:unshelve_and_unpublish)
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
    it 'sets rights to stanford and not change publish or shelve attributes' do
      @item.set_read_rights('stanford')
      expect(@item).not_to receive(:unshelve_and_unpublish)
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
            <group>stanford</group>
          </machine>
        </access>
        <use>
          <human type="creativecommons">Attribution Share Alike license</human>
          <machine type="creativecommons">by-sa</machine>
        </use>
      </rightsMetadata>
      XML
    end
    it 'sets rights to <none/>' do
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
  end

  describe 'add_collection' do
    it 'adds a collection' do
      @item.add_collection('druid:oo201oo0002')
      expect(@item.collection_ids).to include('druid:oo201oo0002')
    end

    it 'adds a collection' do
      @item.add_collection('druid:oo201oo0002')
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
  end

  describe 'remove_collection' do
    it 'deletes a collection' do
      @item.add_collection('druid:oo201oo0002')
      expect(@item.collection_ids).to include('druid:oo201oo0002')
      @item.remove_collection('druid:oo201oo0002')
    end

    it 'deletes a collection' do
      @item.add_collection('druid:oo201oo0002')
      rels_ext_ds = @item.datastreams['RELS-EXT']
      @item.remove_collection('druid:oo201oo0002')
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
    it 'changes the read permissions value from <group>stanford</group> to <none/>' do
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

  describe 'initiate_apo_workflow' do
    it 'calls CreateWorkflowService.create_workflow without creating a datastream when the object is new' do
      expect(Deprecation).to receive(:warn)
      i = GovernableItem.new
      expect(Dor::CreateWorkflowService).to receive(:create_workflow).with(i, name: 'accessionWF', create_ds: false)
      i.initiate_apo_workflow('accessionWF')
    end
  end

  describe 'can_manage_item?' do
    it 'delegates to Dor::Ability' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::Ability).to receive(:can_manage_item?)
      @item.can_manage_item?(['dor-administrator'])
    end
  end

  describe 'can_manage_desc_metadata?' do
    it 'delegates to Dor::Ability' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::Ability).to receive(:can_manage_desc_metadata?)
      @item.can_manage_desc_metadata?(['dor-administrator'])
    end
  end

  describe 'can_manage_content?' do
    it 'delegates to Dor::Ability' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::Ability).to receive(:can_manage_content?)
      @item.can_manage_content?(['dor-administrator'])
    end
  end

  describe 'can_manage_rights?' do
    it 'delegates to Dor::Ability' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::Ability).to receive(:can_manage_rights?)
      @item.can_manage_rights?(['dor-administrator'])
    end
  end

  describe 'can_manage_embargo?' do
    it 'delegates to Dor::Ability' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::Ability).to receive(:can_manage_embargo?)
      @item.can_manage_embargo?(['dor-administrator'])
    end
  end

  describe 'can_view_content?' do
    it 'delegates to Dor::Ability' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::Ability).to receive(:can_view_content?)
      @item.can_view_content?(['dor-administrator'])
    end
  end

  describe 'can_view_metadata?' do
    it 'delegates to Dor::Ability' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::Ability).to receive(:can_view_metadata?)
      @item.can_view_metadata?(['dor-administrator'])
    end
  end

  describe 'reapplyAdminPolicyObjectDefaults' do
    it 'updates rightsMetadata from the APO defaultObjectRights' do
      expect(@item.rightsMetadata.ng_xml.search('//rightsMetadata/access[@type=\'read\']/machine/group').length).to eq(1)
      @apo = instantiate_fixture('druid_zt570tx3016', Dor::AdminPolicyObject)
      expect(@item).to receive(:admin_policy_object).and_return(@apo)
      @item.reapplyAdminPolicyObjectDefaults
      expect(@item.rightsMetadata.ng_xml.search('//rightsMetadata/access[@type=\'read\']/machine/group').length).to eq(0)
      expect(@item.rightsMetadata.ng_xml.search('//rightsMetadata/access[@type=\'read\']/machine/world').length).to eq(1)
    end
  end
end
