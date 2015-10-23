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
    agr.stub(:new? => false, :new_record? => false, :pid => 'druid:new_agreement')
    agr.stub(:save)
    agr
  }

  describe 'add_roleplayer' do
    it 'should add a role' do
      @item.add_roleplayer('dor-apo-manager', 'dlss:some-staff')
      @item.roles.should == {"dor-apo-manager"=>["workgroup:dlss:developers", "workgroup:dlss:pmag-staff", "workgroup:dlss:smpl-staff", "workgroup:dlss:dpg-staff", "workgroup:dlss:argo-access-spec", "sunetid:lmcrae", "workgroup:dlss:some-staff"]}
    end

    it 'should create a new role' do
      @item.add_roleplayer('dor-apo-viewer', 'dlss:some-staff')
      {"dor-apo-manager" => ["workgroup:dlss:developers", "workgroup:dlss:pmag-staff", "workgroup:dlss:smpl-staff", "workgroup:dlss:dpg-staff", "workgroup:dlss:argo-access-spec", "sunetid:lmcrae"],"dor-apo-viewer" => ["workgroup:dlss:some-staff"]}
    end

    it 'should work on an empty datastream' do
      @empty_item.add_roleplayer('dor-apo-manager', 'dlss:some-staff')
      @empty_item.roles.should == {"dor-apo-manager" => ["workgroup:dlss:some-staff"]}
    end
  end

  describe 'default_collections' do
    it 'should fetch the default collections' do
      @item.default_collections.should == ['druid:fz306fj8334']
    end
    it 'shouldnt fail on an item with an empty datastream' do
      @empty_item.default_collections.should == []
    end
  end
  describe 'add_default_collection' do
    it 'should set the collection values' do
      @item.add_default_collection 'druid:fz306fj8335'
      @item.default_collections == ['druid:fz306fj8335']
    end
    it 'should work for empty datastreams' do
      @empty_item.add_default_collection 'druid:fz306fj8335'
      @empty_item.default_collections == ['druid:fz306fj8335']
    end
  end
  describe 'remove_default_collection' do
    it 'should remove the collection' do
      @item.remove_default_collection 'druid:fz306fj8334'
      @item.default_collections.should == []
    end
    it 'should work on an empty datastream' do
      @empty_item.add_default_collection 'druid:fz306fj8335'
      @empty_item.remove_default_collection 'druid:fz306fj8335'
      @empty_item.default_collections.should == []
    end
  end
  describe 'roles' do
    it 'should create a roles has' do
      @item.roles.should == {'dor-apo-manager'=>["workgroup:dlss:developers", "workgroup:dlss:pmag-staff", "workgroup:dlss:smpl-staff", "workgroup:dlss:dpg-staff", "workgroup:dlss:argo-access-spec", "sunetid:lmcrae"]}
    end
    it 'shouldnt fail on an item with an empty datastream' do
      @empty_item.roles.should == {}
    end
  end
  describe 'use_statement' do
    it 'should find the use statement' do
      @item.use_statement.should == 'Rights are owned by Stanford University Libraries. All Rights Reserved. This work is protected by copyright law. No part of the materials may be derived, copied, photocopied, reproduced, translated or reduced to any electronic medium or machine readable form, in whole or in part, without specific permission from the copyright holder. To access this content or to request reproduction permission, please send a written request to speccollref@stanford.edu.'
    end
    it 'shouldnt fail on an item with an empty datastream' do
      @empty_item.use_statement.should == ''
    end
  end

  describe 'use_statement =' do
    it 'should work' do
      @item.use_statement = 'hi'
      @item.use_statement.should == 'hi'
    end
  end

  describe 'copyright_statement' do
    it 'should find the copyright statement' do
      @item.copyright_statement.should == 'Additional copyright info'
    end
    it 'shouldnt fail on an item with an empty datastream' do
      @empty_item.copyright_statement.should == ''
    end
  end
  describe 'copyright_statement =' do
  end
  describe 'metadata_source' do
    it 'should get the metadata source' do
      @item.metadata_source.should == 'MDToolkit'
    end
    it 'should get nil for an empty datastream' do
      @empty_item.metadata_source.should be_nil
    end
  end
  describe 'metadata_source=' do
    it 'should set the metadata source' do
      @item.metadata_source = 'Symphony'
      @item.metadata_source.should == 'Symphony'
    end
    it 'should set the metadata source for an empty datastream' do
      @empty_item.desc_metadata_format = 'TEI'
      @empty_item.metadata_source = 'Symphony'
      @empty_item.metadata_source.should == 'Symphony'
    end
  end
  describe 'creative_commons_license' do
    it 'should find the creative commons license' do
      @item.creative_commons_license.should == 'by-nc-sa'
    end
    it 'shouldnt fail on an item with an empty datastream' do
      @empty_item.creative_commons_license.should == ''
    end
  end
  describe 'creative_commons_human' do
    it 'should find the human readable cc license' do
      @item.creative_commons_license_human.should == 'CC Attribution-NonCommercial-ShareAlike 3.0'
    end
  end
  describe 'creative_commons_license =' do
    it 'should work on an empty ds' do
      @empty_item.creative_commons_license = ['hi']
      @empty_item.creative_commons_license.should == 'hi'
    end
    it 'shouldnt create multiple use nodes' do
      @empty_item.creative_commons_license = 'hi'
      @empty_item.creative_commons_license_human = 'greetings'
      @empty_item.use_statement = 'this is my use statement'
      @empty_item.use_statement.should == 'this is my use statement'
      @empty_item.defaultObjectRights.ng_xml.search("//use").length.should == 1
    end
  end
  describe 'creative_commons_license_human=' do
    it 'should set the human readable cc license' do
      @item.creative_commons_license_human = 'greetings'
      @item.creative_commons_license_human.should == 'greetings'
    end
    it 'should work on an empty ds' do
      @empty_item.creative_commons_license_human = 'greetings'
      @empty_item.creative_commons_license_human.should == 'greetings'
    end
  end
  describe 'default object rights' do
    it 'should find the default object rights' do
      @item.default_rights.should == 'World'
    end
    it 'should use the OM template if the ds is empty' do
      @empty_item.default_rights.should == 'World'
    end
  end
  describe 'default_rights =' do
    it 'should set default rights' do
      @item.default_rights = 'stanford'
      @item.default_rights.should == 'Stanford'
    end
    it 'should work on an empty ds' do
      @empty_item.default_rights = 'stanford'
      @empty_item.default_rights.should == 'Stanford'
    end
  end
  describe 'desc metadata format' do
    it 'should find the desc metadata format' do
      @item.desc_metadata_format.should == 'MODS'
    end
    it 'shouldnt fail on an item with an empty datastream' do
      @empty_item.desc_metadata_format.should be_nil
    end
    it 'should set dark correctly' do
      @item.default_rights = 'dark'
      @item.default_rights.should == 'Dark'
    end
    it 'setters should be case insensitive' do
      @item.default_rights = 'Dark'
      @item.default_rights.should == 'Dark'
    end
    it 'should set read rights to none for dark' do
      @item.default_rights = 'Dark'
      xml=@item.datastreams['defaultObjectRights'].ng_xml
      xml.search('//rightsMetadata/access[@type=\'read\']/machine/none').length.should == 1
    end
  end
  describe 'desc_metadata_format=' do
    it 'should set the desc metadata format' do
      @item.desc_metadata_format = 'TEI'
      @item.desc_metadata_format.should == 'TEI'
    end
    it 'should set the desc metadata format for an empty datastream' do
      @empty_item.desc_metadata_format = 'TEI'
      @empty_item.desc_metadata_format.should == 'TEI'
    end
  end
  describe 'mods_title' do
    it 'should get the title' do
      @item.mods_title.should == 'Ampex'
    end
    it 'shouldnt fail on an item with an empty datastream' do
      @empty_item.mods_title.should == ''
    end
  end
  describe 'mods_title=' do
    it 'should set the title' do
      @item.mods_title = 'hello world'
      @item.mods_title.should == 'hello world'
    end
    it 'should work on an empty datastream' do
      @empty_item.mods_title = 'hello world'
      @empty_item.mods_title.should == 'hello world'
    end
  end
  describe 'default workflows' do
    it 'should find the default workflows' do
      @item.default_workflows.should == ['digitizationWF']
    end
  end
  describe 'copyright_statement=' do
    it 'shoudl work' do
      @item.copyright_statement = 'hi'
      @item.copyright_statement.should == 'hi'
    end
    it 'works on an empty datastream' do
      @empty_item.copyright_statement = 'hi'
      @empty_item.copyright_statement.should == 'hi'
    end
  end
  describe 'purge_roles' do
    it 'works' do
      @item.purge_roles
      @item.roles.should == {}
    end
  end
  describe 'agreement=' do
    it 'should work' do
      agr=double()
      agr.stub(:pid).and_return('druid:dd327qr3670')
      @item.stub(:agreement_object).and_return([agr])
      rels_ext_ds=@item.datastreams['RELS-EXT']
      ActiveFedora::Base.should_receive(:find_one).with('druid:new_agreement', true).and_return(mock_agreement)

      @item.agreement = 'druid:new_agreement'
      xml=Nokogiri::XML(rels_ext_ds.to_rels_ext.to_s)
      xml.should be_equivalent_to <<-XML
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
      @item.default_workflows.include?('thisWF').should == true
    end
    it 'should work on an empty ds' do
      @empty_item.default_workflow = 'thisWF'
      @empty_item.default_workflows.include?('thisWF').should == true
      adm_md_ds = @empty_item.datastreams['administrativeMetadata']
      xml = Nokogiri::XML(adm_md_ds.to_xml)
      xml.should be_equivalent_to <<-XML
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
      @item.stub(:milestones).and_return({})
      @item.stub(:agreement).and_return('druid:agreement')
      @item.stub(:agreement_object).and_return(true)
      solr_doc = @item.to_solr
      solr_doc["default_rights_facet"].should == ['World']
      solr_doc["agreement_facet"].should == ['druid:agreement']
      solr_doc["registration_default_collection_facet"].should == ["druid:fz306fj8334"]
      solr_doc["registration_workflow_id_facet"].should == ['digitizationWF']
      solr_doc["rightsMetadata_use_statement_facet"].should == ["Rights are owned by Stanford University Libraries. All Rights Reserved. This work is protected by copyright law. No part of the materials may be derived, copied, photocopied, reproduced, translated or reduced to any electronic medium or machine readable form, in whole or in part, without specific permission from the copyright holder. To access this content or to request reproduction permission, please send a written request to speccollref@stanford.edu."]
      solr_doc["copyright_facet"].should == ["Additional copyright info"]

    end
  end
end
