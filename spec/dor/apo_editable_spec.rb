require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dor::Editable do
  before(:all) { stub_config   }
  after(:all)  { unstub_config }
  before :each do
    @item = instantiate_fixture("druid_zt570tx3016", Dor::AdminPolicyObject)
    @empty_item = instantiate_fixture("pw570tx3016", Dor::AdminPolicyObject)
  end
  describe 'add_roleplayer' do
    it 'should add a role' do
      @item.add_roleplayer('dor-apo-manager', 'dlss:some-staff')
      puts @item.roleMetadata.ng_xml.to_s
    end

    it 'should create a new role' do
      @item.add_roleplayer('dor-apo-viewer', 'dlss:some-staff')
      puts @item.roleMetadata.ng_xml.to_s
    end

    it 'should work on an empty datastream' do
      @empty_item.add_roleplayer('dor-apo-manager', 'dlss:some-staff')
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

  describe 'set_use_statement' do
    it 'should work' do
      @item.set_use_statement 'hi'
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
  describe 'set_copyright_statement' do
  end
  describe 'creative_commons_license' do
    it 'should find the creative commons license' do
      @item.creative_commons_license.should == 'by-nc-sa'
    end
    it 'shouldnt fail on an item with an empty datastream' do
      @empty_item.creative_commons_license.should == ''
    end
  end
  describe 'set_creative_commons_license' do
    it 'should work on an empty ds' do
      @empty_item.set_creative_commons_license 'hi'
      @empty_item.creative_commons_license.should == 'hi'
    end
  end
  describe 'default object rights' do
    it 'should find the default object rights' do
      @item.default_rights.should == 'World'
    end
    it 'shouldnt fail on an item with an empty datastream' do
      @empty_item.default_rights.should == 'None'
    end
  end
  describe 'desc metadata format' do
    it 'should find the desc metadata format' do
      @item.desc_metadata_format.should == 'MODS'
    end
    it 'shouldnt fail on an item with an empty datastream' do
      @empty_item.desc_metadata_format.should == ''
    end
  end
  describe 'set_desc_metadata_format' do
    it 'should set the desc metadata format' do
      @item.set_desc_metadata_format 'TEI'
      @item.desc_metadata_format.should == 'TEI'
    end
    it 'should set the desc metadata format for an empty datastream' do
      @empty_item.set_desc_metadata_format 'TEI'
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
  describe 'set_mods_title' do
    it 'should set the title' do
    @item.set_mods_title 'hello world'
    @item.mods_title.should == 'hello world'
    end
    it 'should work on an empty datastream' do
      @empty_item.set_mods_title 'hello world'
      @empty_item.mods_title.should == 'hello world'
    end
  end
  describe 'default workflows' do
    it 'should find the default workflows' do
      @item.default_workflows.should == ['digitizationWF']
    end
    it '' do
      @item.set_copyright_statement 'hi'
      puts @item.defaultObjectRights.ng_xml.to_s
    end
  end
  describe 'agreement' do
    it 'should get an agreement' do
      @item.agreement.should == 'druid:xf765cv5573'
    end
    it 'shouldnt fail on an empty datastream' do
      @empty_item.agreement.should == ''
    end
  end
end