require 'spec_helper'

describe Dor::Editable do
  before(:each) { stub_config   }
  after(:each)  { unstub_config }
  before :each do
    @apo = instantiate_fixture('druid_zt570tx3016', Dor::AdminPolicyObject)
    @empty_item = instantiate_fixture('pw570tx3016', Dor::AdminPolicyObject)
  end

  describe 'add_roleplayer' do
    it 'should add a role' do
      @apo.add_roleplayer('dor-apo-manager', 'dlss:some-staff')
      exp_result = {
        'dor-apo-manager' => [
          'workgroup:dlss:developers', 'workgroup:dlss:pmag-staff', 'workgroup:dlss:smpl-staff', 'workgroup:dlss:dpg-staff',
          'workgroup:dlss:argo-access-spec', 'sunetid:lmcrae', 'workgroup:dlss:some-staff']}
      expect(@apo.roles).to eq exp_result
    end

    it 'should create a new role' do
      @apo.add_roleplayer('dor-apo-viewer', 'dlss:some-staff')
      exp_result = {
        'dor-apo-manager' => [
          'workgroup:dlss:developers', 'workgroup:dlss:pmag-staff', 'workgroup:dlss:smpl-staff', 'workgroup:dlss:dpg-staff',
          'workgroup:dlss:argo-access-spec', 'sunetid:lmcrae'],
        'dor-apo-viewer' => ['workgroup:dlss:some-staff']}
      expect(@apo.roles).to eq exp_result
    end

    it 'should work on an empty datastream' do
      @empty_item.add_roleplayer('dor-apo-manager', 'dlss:some-staff')
      expect(@empty_item.roles).to eq({'dor-apo-manager' => ['workgroup:dlss:some-staff']})
    end
  end

  describe 'default_collections' do
    it 'should fetch the default collections' do
      expect(@apo.default_collections).to eq(['druid:fz306fj8334'])
    end
    it 'should not fail on an item with an empty datastream' do
      expect(@empty_item.default_collections).to eq([])
    end
  end
  describe 'add_default_collection' do
    it 'should set the collection values' do
      @apo.add_default_collection 'druid:fz306fj8335'
      expect(@apo.default_collections).to eq ['druid:fz306fj8334', 'druid:fz306fj8335']
    end
    it 'should work for empty datastreams' do
      @empty_item.add_default_collection 'druid:fz306fj8335'
      expect(@empty_item.default_collections).to eq ['druid:fz306fj8335']
    end
  end
  describe 'remove_default_collection' do
    it 'should remove the collection' do
      @apo.remove_default_collection 'druid:fz306fj8334'
      expect(@apo.default_collections).to eq([])
    end
    it 'should work on an empty datastream' do
      @empty_item.add_default_collection 'druid:fz306fj8335'
      @empty_item.remove_default_collection 'druid:fz306fj8335'
      expect(@empty_item.default_collections).to eq([])
    end
  end
  describe 'roles' do
    it 'should create a roles hash' do
      exp_result = {
        'dor-apo-manager' => [
          'workgroup:dlss:developers', 'workgroup:dlss:pmag-staff', 'workgroup:dlss:smpl-staff',
          'workgroup:dlss:dpg-staff', 'workgroup:dlss:argo-access-spec', 'sunetid:lmcrae']}
      expect(@apo.roles).to eq exp_result
    end
    it 'should not fail on an item with an empty datastream' do
      expect(@empty_item.roles).to eq({})
    end
  end
  describe 'use_statement' do
    it 'should find the use statement' do
      expect(@apo.use_statement).to eq('Rights are owned by Stanford University Libraries. All Rights Reserved. This work is protected by copyright law. No part of the materials may be derived, copied, photocopied, reproduced, translated or reduced to any electronic medium or machine readable form, in whole or in part, without specific permission from the copyright holder. To access this content or to request reproduction permission, please send a written request to speccollref@stanford.edu.')
    end
    it 'should not fail on an item with an empty datastream' do
      expect(@empty_item.use_statement).to eq('')
    end
  end

  describe 'use_statement=' do
    it 'should assign use statement' do
      @apo.use_statement = 'hi'
      expect(@apo.use_statement).to eq('hi')
    end
    it 'should assign null use statements' do
      ['  ', nil].each do |v|
        @apo.use_statement = v
        expect(@apo.use_statement).to be_nil
        expect(@apo.defaultObjectRights.ng_xml.at_xpath('/rightsMetadata/use/human[@type="useAndReproduction"]')).to be_nil
      end
    end
    it 'should fail if trying to set use statement after it is null' do
      @apo.use_statement = nil
      expect { @apo.use_statement = 'force fail' }.not_to raise_error
    end
  end

  describe 'copyright_statement' do
    it 'should find the copyright statement' do
      expect(@apo.copyright_statement).to eq('Additional copyright info')
    end
    it 'should not fail on an item with an empty datastream' do
      expect(@empty_item.copyright_statement).to eq('')
    end
  end
  describe 'copyright_statement =' do
    it 'should assign copyright' do
      @apo.copyright_statement = 'hi'
      expect(@apo.copyright_statement).to eq('hi')
      doc = Nokogiri::XML(@apo.defaultObjectRights.content)
      expect(doc.at_xpath('/rightsMetadata/copyright/human[@type="copyright"]').text).to eq('hi')
    end
    it 'should assign null copyright' do
      @apo.copyright_statement = nil
      expect(@apo.copyright_statement).to be_nil
      doc = Nokogiri::XML(@apo.defaultObjectRights.content)
      expect(doc.at_xpath('/rightsMetadata/copyright')).to be_nil
      expect(doc.at_xpath('/rightsMetadata/copyright/human[@type="copyright"]')).to be_nil
    end
    it 'should assign blank copyright' do
      @apo.copyright_statement = ' '
      expect(@apo.copyright_statement).to be_nil
    end
    it 'should error if assigning copyright after removing one' do
      @apo.copyright_statement = nil
      @apo.copyright_statement = nil # call twice to ensure repeatability
      expect { @apo.copyright_statement = 'will fail' }.not_to raise_error
    end
  end
  describe 'metadata_source' do
    it 'should get the metadata source' do
      expect(@apo.metadata_source).to eq('MDToolkit')
    end
    it 'should get nil for an empty datastream' do
      expect(@empty_item.metadata_source).to eq(nil)
    end
  end
  describe 'metadata_source=' do
    it 'should set the metadata source' do
      @apo.metadata_source = 'Symphony'
      expect(@apo.metadata_source).to eq('Symphony')
    end
    it 'should set the metadata source for an empty datastream' do
      @empty_item.desc_metadata_format = 'TEI'
      @empty_item.metadata_source = 'Symphony'
      expect(@empty_item.metadata_source).to eq('Symphony')
    end
  end
  describe 'creative_commons_license' do
    it 'should find the creative commons license' do
      expect(@apo.creative_commons_license).to eq('by-nc-sa')
    end
    it 'should not fail on an item with an empty datastream' do
      expect(@empty_item.creative_commons_license).to eq('')
    end
  end
  describe 'creative_commons_human' do
    it 'should find the human readable cc license' do
      expect(@apo.creative_commons_license_human).to eq('CC Attribution-NonCommercial-ShareAlike 3.0')
    end
  end
  describe 'creative_commons_license=' do
    # these are less relevant now that we're moving to use_license= and away from setting individual use license components so directly
    it 'should work on an empty ds' do
      @empty_item.creative_commons_license = 'by-nc'
      expect(@empty_item.creative_commons_license).to eq('by-nc')
    end
    it 'should not create multiple use nodes' do
      @empty_item.creative_commons_license = 'pdm'
      @empty_item.creative_commons_license_human = 'greetings'
      @empty_item.use_statement = 'this is my use statement'
      expect(@empty_item.use_statement).to eq('this is my use statement')
      expect(@empty_item.creative_commons_license_human).to eq 'greetings'
      expect(@empty_item.creative_commons_license).to eq 'pdm'
      expect(@empty_item.defaultObjectRights.ng_xml.search('//use').length).to eq(1)
    end
  end
  describe 'creative_commons_license_human=' do
    it 'should set the human readable cc license' do
      @apo.creative_commons_license_human = 'greetings'
      expect(@apo.creative_commons_license_human).to eq('greetings')
    end
    it 'should work on an empty ds' do
      @empty_item.creative_commons_license_human = 'greetings'
      expect(@empty_item.creative_commons_license_human).to eq('greetings')
    end
  end
  describe 'use_license=' do
    it 'should set the machine and human readable CC licenses given the right license code' do
      use_license_machine = 'by-nc-nd'
      use_license_uri   = Dor::Editable::CREATIVE_COMMONS_USE_LICENSES[use_license_machine][:uri]
      use_license_human = Dor::Editable::CREATIVE_COMMONS_USE_LICENSES[use_license_machine][:human_readable]
      @empty_item.use_license = use_license_machine
      expect(@empty_item.use_license).to eq(use_license_machine)
      expect(@empty_item.use_license_uri).to eq(use_license_uri)
      expect(@empty_item.use_license_human).to eq(use_license_human)
      expect(@empty_item.creative_commons_license).to eq(use_license_machine)
      expect(@empty_item.creative_commons_license_human).to eq(use_license_human)
      expect(@empty_item.open_data_commons_license).to eq('')
      expect(@empty_item.open_data_commons_license_human).to eq('')
    end
    it 'should set the machine and human readable ODC licenses given the right license code' do
      use_license_machine = 'odc-by'
      use_license_human   = Dor::Editable::OPEN_DATA_COMMONS_USE_LICENSES[use_license_machine][:human_readable]
      @empty_item.use_license = use_license_machine
      expect(@empty_item.use_license).to eq(use_license_machine)
      expect(@empty_item.use_license_human).to eq(use_license_human)
      expect(@empty_item.creative_commons_license).to eq('')
      expect(@empty_item.creative_commons_license_human).to eq('')
      expect(@empty_item.open_data_commons_license).to eq(use_license_machine)
      expect(@empty_item.open_data_commons_license_human).to eq(use_license_human)
    end
    it 'should throw an exception if no valid license code is given' do
      expect { @empty_item.use_license = 'something-unexpected' }.to raise_exception(ArgumentError)
      expect(@empty_item.use_license).to eq('')
      expect(@empty_item.use_license_human).to eq('')
    end
    it 'should be able to remove the use license' do
      [:none, '  ', nil].each do |v|
        @apo.use_license = v
        expect(@apo.use_license).to eq('')
        expect(@apo.use_license_uri).to be_nil
        expect(@apo.use_license_human).to eq('')
        expect(@apo.creative_commons_license).to be_nil
        expect(@apo.creative_commons_license_human).to be_nil
        expect(@apo.open_data_commons_license).to be_nil
        expect(@apo.open_data_commons_license_human).to be_nil
      end
    end
  end
  describe 'default object rights' do
    it 'should find the default object rights' do
      expect(@apo.default_rights).to eq('World')
    end
    it 'should use the OM template if the ds is empty' do
      expect(@empty_item.default_rights).to eq('World')
    end
  end
  describe 'default_rights=' do
    it 'should set default rights' do
      @apo.default_rights = 'stanford'
      expect(@apo.default_rights).to eq('Stanford')
    end
    it 'should work on an empty ds' do
      @empty_item.default_rights = 'stanford'
      expect(@empty_item.default_rights).to eq('Stanford')
    end
  end
  describe 'desc metadata format' do
    it 'should find the desc metadata format' do
      expect(@apo.desc_metadata_format).to eq('MODS')
    end
    it 'should not fail on an item with an empty datastream' do
      expect(@empty_item.desc_metadata_format).to eq(nil)
    end
    it 'should set dark correctly' do
      @apo.default_rights = 'dark'
      expect(@apo.default_rights).to eq('Dark')
    end
    it 'setters should be case insensitive' do
      @apo.default_rights = 'Dark'
      expect(@apo.default_rights).to eq('Dark')
    end
    it 'should set read rights to none for dark' do
      @apo.default_rights = 'Dark'
      xml = @apo.datastreams['defaultObjectRights'].ng_xml
      expect(xml.search('//rightsMetadata/access[@type=\'read\']/machine/none').length).to eq(1)
    end
  end
  describe 'desc_metadata_format=' do
    it 'should set the desc metadata format' do
      @apo.desc_metadata_format = 'TEI'
      expect(@apo.desc_metadata_format).to eq('TEI')
    end
    it 'should set the desc metadata format for an empty datastream' do
      @empty_item.desc_metadata_format = 'TEI'
      expect(@empty_item.desc_metadata_format).to eq('TEI')
    end
  end
  describe 'mods_title' do
    it 'should get the title' do
      expect(@apo.mods_title).to eq('Ampex')
    end
    it 'should not fail on an item with an empty datastream' do
      expect(@empty_item.mods_title).to eq('')
    end
  end
  describe 'mods_title=' do
    it 'should set the title' do
      @apo.mods_title = 'hello world'
      expect(@apo.mods_title).to eq('hello world')
    end
    it 'should work on an empty datastream' do
      @empty_item.mods_title = 'hello world'
      expect(@empty_item.mods_title).to eq('hello world')
    end
  end
  describe 'default workflows' do
    it 'should find the default workflows' do
      expect(@apo.default_workflows).to eq(['digitizationWF'])
    end
    it 'should be able to set default workflows' do
      @apo.default_workflow = 'accessionWF'
      expect(@apo.default_workflows).to eq(['accessionWF'])
    end
    it 'should NOT be able to set a null default workflows' do
      expect { @apo.default_workflow = '' }.to raise_error(ArgumentError)
      expect(@apo.default_workflows).to eq(['digitizationWF']) # the original default workflow
    end
  end
  describe 'copyright_statement=' do
    it 'should assign' do
      @apo.copyright_statement = 'hi'
      expect(@apo.copyright_statement).to eq('hi')
    end
    it 'works on an empty datastream' do
      @empty_item.copyright_statement = 'hi'
      expect(@empty_item.copyright_statement).to eq('hi')
    end
  end
  describe 'purge_roles' do
    it 'works' do
      @apo.purge_roles
      expect(@apo.roles).to eq({})
    end
  end

  describe 'agreement=' do
    it 'should assign' do
      skip 'dispatches "belongs_to" association for agreement_object down into internals of ActiveFedora'
    end
  end

  describe 'default_workflow=' do
    it 'should set the default workflow' do
      @apo.default_workflow = 'thisWF'
      expect(@apo.default_workflows).to include('thisWF')
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
      allow(@apo).to receive(:milestones).and_return({})
      allow(@apo).to receive(:agreement).and_return('druid:agreement')
      allow(@apo).to receive(:agreement_object).and_return(true)
      solr_doc = @apo.to_solr
      expect(solr_doc).to match a_hash_including('default_rights_ssim' => ['World'])
      expect(solr_doc).to match a_hash_including('agreement_ssim'      => ['druid:agreement'])
      # expect(solr_doc).to match a_hash_including("registration_default_collection_sim" => ["druid:fz306fj8334"])
      expect(solr_doc).to match a_hash_including('registration_workflow_id_ssim' => ['digitizationWF'])
      expect(solr_doc).to match a_hash_including('use_statement_ssim'  => ['Rights are owned by Stanford University Libraries. All Rights Reserved. This work is protected by copyright law. No part of the materials may be derived, copied, photocopied, reproduced, translated or reduced to any electronic medium or machine readable form, in whole or in part, without specific permission from the copyright holder. To access this content or to request reproduction permission, please send a written request to speccollref@stanford.edu.'])
      expect(solr_doc).to match a_hash_including('copyright_ssim'      => ['Additional copyright info'])
      expect(solr_doc).to match a_hash_including('default_use_license_machine_ssi' => 'by-nc-sa')
    end
  end
end
