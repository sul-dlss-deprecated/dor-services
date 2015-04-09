require 'spec_helper'

describe Dor::Editable do
  before(:each) { stub_config   }
  after(:each)  { unstub_config }
  before :each do
    @item = instantiate_fixture("druid_zt570tx3016", Dor::AdminPolicyObject)
    @empty_item = instantiate_fixture("pw570tx3016", Dor::AdminPolicyObject)
  end

  let(:mock_agreement) {
    agr = Dor::Item.new
    allow(agr).to receive(:new?).and_return false
    allow(agr).to receive(:new_record?).and_return false
    allow(agr).to receive(:pid).and_return 'druid:new_agreement'
    allow(agr).to receive(:save)
    agr
  }

  describe 'add_roleplayer' do
    it 'should add a role' do
      @item.add_roleplayer('dor-apo-manager', 'dlss:some-staff')
      expect(@item.roles).to eq({"dor-apo-manager"=>["workgroup:dlss:developers", "workgroup:dlss:pmag-staff", "workgroup:dlss:smpl-staff", "workgroup:dlss:dpg-staff", "workgroup:dlss:argo-access-spec", "sunetid:lmcrae", "workgroup:dlss:some-staff"]})
    end

    it 'should create a new role' do
      @item.add_roleplayer('dor-apo-viewer', 'dlss:some-staff')
      {"dor-apo-manager" => ["workgroup:dlss:developers", "workgroup:dlss:pmag-staff", "workgroup:dlss:smpl-staff", "workgroup:dlss:dpg-staff", "workgroup:dlss:argo-access-spec", "sunetid:lmcrae"],"dor-apo-viewer" => ["workgroup:dlss:some-staff"]}
    end

    it 'should work on an empty datastream' do
      @empty_item.add_roleplayer('dor-apo-manager', 'dlss:some-staff')
      expect(@empty_item.roles).to eq({"dor-apo-manager" => ["workgroup:dlss:some-staff"]})
    end
  end

  describe 'default_collections' do
    it 'should fetch the default collections' do
      expect(@item.default_collections).to eq(['druid:fz306fj8334'])
    end
    it 'should not fail on an item with an empty datastream' do
      expect(@empty_item.default_collections).to eq([])
    end
  end
  describe 'add_default_collection' do
    it 'should set the collection values' do
      @item.add_default_collection 'druid:fz306fj8335'
      expect(@item.default_collections).to eq ['druid:fz306fj8334','druid:fz306fj8335']
    end
    it 'should work for empty datastreams' do
      @empty_item.add_default_collection 'druid:fz306fj8335'
      expect(@empty_item.default_collections).to eq ['druid:fz306fj8335']
    end
  end
  describe 'remove_default_collection' do
    it 'should remove the collection' do
      @item.remove_default_collection 'druid:fz306fj8334'
      expect(@item.default_collections).to eq([])
    end
    it 'should work on an empty datastream' do
      @empty_item.add_default_collection 'druid:fz306fj8335'
      @empty_item.remove_default_collection 'druid:fz306fj8335'
      expect(@empty_item.default_collections).to eq([])
    end
  end
  describe 'roles' do
    it 'should create a roles hash' do
      expect(@item.roles).to eq({'dor-apo-manager'=>["workgroup:dlss:developers", "workgroup:dlss:pmag-staff", "workgroup:dlss:smpl-staff", "workgroup:dlss:dpg-staff", "workgroup:dlss:argo-access-spec", "sunetid:lmcrae"]})
    end
    it 'should not fail on an item with an empty datastream' do
      expect(@empty_item.roles).to eq({})
    end
  end
  describe 'use_statement' do
    it 'should find the use statement' do
      expect(@item.use_statement).to eq('Rights are owned by Stanford University Libraries. All Rights Reserved. This work is protected by copyright law. No part of the materials may be derived, copied, photocopied, reproduced, translated or reduced to any electronic medium or machine readable form, in whole or in part, without specific permission from the copyright holder. To access this content or to request reproduction permission, please send a written request to speccollref@stanford.edu.')
    end
    it 'should not fail on an item with an empty datastream' do
      expect(@empty_item.use_statement).to eq('')
    end
  end

  describe 'use_statement=' do
    it 'should work' do
      @item.use_statement = 'hi'
      expect(@item.use_statement).to eq('hi')
    end
  end

  describe 'copyright_statement' do
    it 'should find the copyright statement' do
      expect(@item.copyright_statement).to eq('Additional copyright info')
    end
    it 'shouldnt fail on an item with an empty datastream' do
      expect(@empty_item.copyright_statement).to eq('')
    end
  end
  describe 'copyright_statement =' do
    pending "Test not implemented"
  end
  describe 'metadata_source' do
    it 'should get the metadata source' do
      expect(@item.metadata_source).to eq('MDToolkit')
    end
    it 'should get nil for an empty datastream' do
      expect(@empty_item.metadata_source).to eq(nil)
    end
  end
  describe 'metadata_source=' do
    it 'should set the metadata source' do
      @item.metadata_source = 'Symphony'
      expect(@item.metadata_source).to eq('Symphony')
    end
    it 'should set the metadata source for an empty datastream' do
      @empty_item.desc_metadata_format = 'TEI'
      @empty_item.metadata_source = 'Symphony'
      expect(@empty_item.metadata_source).to eq('Symphony')
    end
  end
  describe 'creative_commons_license' do
    it 'should find the creative commons license' do
      expect(@item.creative_commons_license).to eq('by-nc-sa')
    end
    it 'shouldnt fail on an item with an empty datastream' do
      expect(@empty_item.creative_commons_license).to eq('')
    end
  end
  describe 'creative_commons_human' do
    it 'should find the human readable cc license' do
      expect(@item.creative_commons_license_human).to eq('CC Attribution-NonCommercial-ShareAlike 3.0')
    end
  end
  describe 'creative_commons_license=' do
    it 'should work on an empty ds' do
      @empty_item.creative_commons_license = ['hi']
      expect(@empty_item.creative_commons_license).to eq('hi')
    end
    it 'should not create multiple use nodes' do
      @empty_item.creative_commons_license = 'hi'
      @empty_item.creative_commons_license_human = 'greetings'
      @empty_item.use_statement = 'this is my use statement'
      expect(@empty_item.use_statement).to eq('this is my use statement')
      expect(@empty_item.defaultObjectRights.ng_xml.search("//use").length).to eq(1)
    end
  end
  describe 'creative_commons_license_human=' do
    it 'should set the human readable cc license' do
      @item.creative_commons_license_human='greetings'
      expect(@item.creative_commons_license_human).to eq('greetings')
    end
    it 'should work on an empty ds' do
      @empty_item.creative_commons_license_human='greetings'
      expect(@empty_item.creative_commons_license_human).to eq('greetings')
    end
  end
  describe 'default object rights' do
    it 'should find the default object rights' do
      expect(@item.default_rights).to eq('World')
    end
    it 'should use the OM template if the ds is empty' do
      expect(@empty_item.default_rights).to eq('World')
    end
  end
  describe 'default_rights=' do
    it 'should set default rights' do
      @item.default_rights = 'stanford'
      expect(@item.default_rights).to eq('Stanford')
    end
    it 'should work on an empty ds' do
      @empty_item.default_rights = 'stanford'
      expect(@empty_item.default_rights).to eq('Stanford')
    end
  end
  describe 'desc metadata format' do
    it 'should find the desc metadata format' do
      expect(@item.desc_metadata_format).to eq('MODS')
    end
    it 'should not fail on an item with an empty datastream' do
      expect(@empty_item.desc_metadata_format).to eq(nil)
    end
    it 'should set dark correctly' do
      @item.default_rights = 'dark'
      expect(@item.default_rights).to eq('Dark')
    end
    it 'setters should be case insensitive' do
      @item.default_rights = 'Dark'
      expect(@item.default_rights).to eq('Dark')
    end
    it 'should set read rights to none for dark' do
      @item.default_rights = 'Dark'
      xml=@item.datastreams['defaultObjectRights'].ng_xml
      expect(xml.search('//rightsMetadata/access[@type=\'read\']/machine/none').length).to eq(1)
    end
  end
  describe 'desc_metadata_format=' do
    it 'should set the desc metadata format' do
      @item.desc_metadata_format = 'TEI'
      expect(@item.desc_metadata_format).to eq('TEI')
    end
    it 'should set the desc metadata format for an empty datastream' do
      @empty_item.desc_metadata_format = 'TEI'
      expect(@empty_item.desc_metadata_format).to eq('TEI')
    end
  end
  describe 'mods_title' do
    it 'should get the title' do
      expect(@item.mods_title).to eq('Ampex')
    end
    it 'shouldnt fail on an item with an empty datastream' do
      expect(@empty_item.mods_title).to eq('')
    end
  end
  describe 'mods_title=' do
    it 'should set the title' do
      @item.mods_title = 'hello world'
      expect(@item.mods_title).to eq('hello world')
    end
    it 'should work on an empty datastream' do
      @empty_item.mods_title = 'hello world'
      expect(@empty_item.mods_title).to eq('hello world')
    end
  end
  describe 'default workflows' do
    it 'should find the default workflows' do
      expect(@item.default_workflows).to eq(['digitizationWF'])
    end
  end
  describe 'copyright_statement=' do
    it 'should assign' do
      @item.copyright_statement = 'hi'
      expect(@item.copyright_statement).to eq('hi')
    end
    it 'works on an empty datastream' do
      @empty_item.copyright_statement = 'hi'
      expect(@empty_item.copyright_statement).to eq('hi')
    end
  end
  describe 'purge_roles' do
    it 'works' do
      @item.purge_roles
      expect(@item.roles).to eq({})
    end
  end
  describe 'agreement=' do
    it 'should assign' do
      pending "this test is probably checking AF internals"
      agr=double()
      allow(agr).to receive(:pid).and_return('druid:dd327qr3670')
      allow(@item).to receive(:agreement_object).and_return([agr])
      rels_ext_ds=@item.datastreams['RELS-EXT']
      expect(ActiveFedora::Base).to receive(:find_one).with('druid:new_agreement', true).and_return(mock_agreement)
      @item.agreement = 'druid:new_agreement'
      xml=Nokogiri::XML(rels_ext_ds.to_rels_ext.to_s)
      expect(xml).to be_equivalent_to <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:hydra="http://projecthydra.org/ns/relations#">
        <rdf:Description rdf:about="info:fedora/druid:zt570tx3016">
          <hydra:isGovernedBy rdf:resource="info:fedora/druid:hv992ry2431"/>
          <hydra:referencesAgreement rdf:resource="info:fedora/druid:new_agreement"/>
        </rdf:Description>
      </rdf:RDF>
      XML
    end

  end
  describe 'default_workflow=' do
    it 'should set the default workflow' do
      @item.default_workflow = 'thisWF'
      expect(@item.default_workflows).to include('thisWF')
    end
    it 'should work on an empty ds' do
      @empty_item.default_workflow = 'thisWF'
      expect(@empty_item.default_workflows).to include('thisWF')
      adm_md_ds = @empty_item.datastreams['administrativeMetadata']
      xml = Nokogiri::XML(adm_md_ds.to_xml)
      expect(xml).to be_equivalent_to <<-XML
        <administrativeMetadata>
          <registration>
            <workflow id="thisWF"/>
          </registration>
        </administrativeMetadata>
      XML
    end
  end
  describe 'to_solr' do
    it 'should make a solr doc' do
      allow(@item).to receive(:milestones).and_return({})
      allow(@item).to receive(:agreement).and_return('druid:agreement')
      allow(@item).to receive(:agreement_object).and_return(true)
      solr_doc = @item.to_solr
      expect(solr_doc).to match a_hash_including(
        "default_rights_sim" => ['World'],
        "agreement_sim"      => ['druid:agreement'],
    #   "registration_default_collection_sim" => ["druid:fz306fj8334"],
        "registration_workflow_id_sim" => ['digitizationWF'],
        "use_statement_sim"  => ["Rights are owned by Stanford University Libraries. All Rights Reserved. This work is protected by copyright law. No part of the materials may be derived, copied, photocopied, reproduced, translated or reduced to any electronic medium or machine readable form, in whole or in part, without specific permission from the copyright holder. To access this content or to request reproduction permission, please send a written request to speccollref@stanford.edu."],
        "copyright_sim"      => ["Additional copyright info"]
      )
    end
  end
end
