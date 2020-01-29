# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::AdminPolicyObject do
  before do
    @apo = instantiate_fixture('druid_zt570tx3016', described_class)
    @empty_item = instantiate_fixture('pw570tx3016', described_class)
  end

  describe 'datastreams' do
    subject { described_class.ds_specs.keys }

    it do
      expect(subject).to match_array %w[RELS-EXT DC identityMetadata
                                        events rightsMetadata descMetadata versionMetadata
                                        administrativeMetadata roleMetadata
                                        defaultObjectRights provenanceMetadata]
    end
  end

  describe '#read_rights=' do
    subject(:set_read_rights) { item.read_rights = rights }

    let(:item) { instantiate_fixture('druid:oo201oo0001', described_class) }

    before do
      allow(item).to receive(:unshelve_and_unpublish)
    end

    context 'when set to an unacceptable value' do
      let(:rights) { 'mambo' }

      it 'raises an exception if the rights option doesnt match the accepted values' do
        expect { set_read_rights }.to raise_error(ArgumentError)
      end
    end

    context 'when set to dark' do
      let(:rights) { 'dark' }
      let(:item) { instantiate_fixture('druid:oo201oo0001', described_class) }

      it 'sets rights to dark (double none), removing the discovery rights' do
        set_read_rights
        expect(item.rightsMetadata.ng_xml).to be_equivalent_to <<-XML
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
    end

    context 'when set to world' do
      let(:rights) { 'world' }

      it 'does not change publish or shelve attributes' do
        set_read_rights
        expect(item).not_to have_received(:unshelve_and_unpublish)
        expect(item.rightsMetadata.ng_xml).to be_equivalent_to <<-XML
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
    end

    context 'when set to stanford' do
      let(:rights) { 'stanford' }

      it 'does not change publish or shelve attributes' do
        set_read_rights
        expect(item).not_to have_received(:unshelve_and_unpublish)
        expect(item.rightsMetadata.ng_xml).to be_equivalent_to <<-XML
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
    end

    context 'when set to none' do
      let(:rights) { 'none' }

      it 'sets rights to <none/>' do
        set_read_rights

        expect(item.rightsMetadata.ng_xml).to be_equivalent_to <<-XML
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

      it 'changes the read permissions value from <group>stanford</group> to <none/>' do
        expect(item.rightsMetadata.ng_xml).to be_equivalent_to <<-XML
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
        set_read_rights
        expect(item.rightsMetadata.ng_xml).to be_equivalent_to <<-XML
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
  end

  describe 'add_roleplayer' do
    it 'adds a role' do
      @apo.add_roleplayer('dor-apo-manager', 'dlss:some-staff')
      exp_result = {
        'dor-apo-manager' => [
          'workgroup:dlss:developers', 'workgroup:dlss:pmag-staff', 'workgroup:dlss:smpl-staff', 'workgroup:dlss:dpg-staff',
          'workgroup:dlss:argo-access-spec', 'sunetid:lmcrae', 'workgroup:dlss:some-staff'
        ]
      }
      expect(@apo.roles).to eq exp_result
    end

    it 'creates a new role' do
      @apo.add_roleplayer('dor-apo-viewer', 'dlss:some-staff')
      exp_result = {
        'dor-apo-manager' => [
          'workgroup:dlss:developers', 'workgroup:dlss:pmag-staff', 'workgroup:dlss:smpl-staff', 'workgroup:dlss:dpg-staff',
          'workgroup:dlss:argo-access-spec', 'sunetid:lmcrae'
        ],
        'dor-apo-viewer' => ['workgroup:dlss:some-staff']
      }
      expect(@apo.roles).to eq exp_result
    end

    it 'works on an empty datastream' do
      @empty_item.add_roleplayer('dor-apo-manager', 'dlss:some-staff')
      expect(@empty_item.roles).to eq('dor-apo-manager' => ['workgroup:dlss:some-staff'])
    end
  end

  describe 'default_collections' do
    it 'fetches the default collections' do
      expect(@apo.default_collections).to eq(['druid:fz306fj8334'])
    end

    it 'does not fail on an item with an empty datastream' do
      expect(@empty_item.default_collections).to eq([])
    end
  end

  describe 'add_default_collection' do
    it 'sets the collection values' do
      @apo.add_default_collection 'druid:fz306fj8335'
      expect(@apo.default_collections).to eq ['druid:fz306fj8334', 'druid:fz306fj8335']
    end

    it 'works for empty datastreams' do
      @empty_item.add_default_collection 'druid:fz306fj8335'
      expect(@empty_item.default_collections).to eq ['druid:fz306fj8335']
    end
  end

  describe 'remove_default_collection' do
    it 'removes the collection' do
      @apo.remove_default_collection 'druid:fz306fj8334'
      expect(@apo.default_collections).to eq([])
    end

    it 'works on an empty datastream' do
      @empty_item.add_default_collection 'druid:fz306fj8335'
      @empty_item.remove_default_collection 'druid:fz306fj8335'
      expect(@empty_item.default_collections).to eq([])
    end
  end

  describe 'roles' do
    it 'creates a roles hash' do
      exp_result = {
        'dor-apo-manager' => [
          'workgroup:dlss:developers', 'workgroup:dlss:pmag-staff', 'workgroup:dlss:smpl-staff',
          'workgroup:dlss:dpg-staff', 'workgroup:dlss:argo-access-spec', 'sunetid:lmcrae'
        ]
      }
      expect(@apo.roles).to eq exp_result
    end

    it 'does not fail on an item with an empty datastream' do
      expect(@empty_item.roles).to eq({})
    end
  end

  describe 'use_statement' do
    it 'finds the use statement' do
      expect(@apo.use_statement).to eq('Rights are owned by Stanford University Libraries. ' \
        'All Rights Reserved. This work is protected by copyright law. No part of the ' \
        'materials may be derived, copied, photocopied, reproduced, translated or reduced ' \
        'to any electronic medium or machine readable form, in whole or in part, without ' \
        'specific permission from the copyright holder. To access this content or to ' \
        'request reproduction permission, please send a written request to speccollref@stanford.edu.')
    end

    it 'does not fail on an item with an empty datastream' do
      expect(@empty_item.use_statement).to eq('')
    end
  end

  describe 'use_statement=' do
    it 'assigns use statement' do
      @apo.use_statement = 'hi'
      expect(@apo.use_statement).to eq('hi')
    end

    it 'assigns null use statements' do
      ['  ', nil].each do |v|
        @apo.use_statement = v
        expect(@apo.use_statement).to be_nil
        expect(@apo.defaultObjectRights.ng_xml.at_xpath('/rightsMetadata/use/human[@type="useAndReproduction"]')).to be_nil
      end
    end

    it 'fails if trying to set use statement after it is null' do
      @apo.use_statement = nil
      expect { @apo.use_statement = 'force fail' }.not_to raise_error
    end
  end

  describe 'copyright_statement' do
    it 'finds the copyright statement' do
      expect(@apo.copyright_statement).to eq('Additional copyright info')
    end

    it 'does not fail on an item with an empty datastream' do
      expect(@empty_item.copyright_statement).to eq('')
    end
  end

  describe 'copyright_statement =' do
    it 'assigns copyright' do
      @apo.copyright_statement = 'hi'
      expect(@apo.copyright_statement).to eq('hi')
      doc = Nokogiri::XML(@apo.defaultObjectRights.content)
      expect(doc.at_xpath('/rightsMetadata/copyright/human[@type="copyright"]').text).to eq('hi')
    end

    it 'assigns null copyright' do
      @apo.copyright_statement = nil
      expect(@apo.copyright_statement).to be_nil
      doc = Nokogiri::XML(@apo.defaultObjectRights.content)
      expect(doc.at_xpath('/rightsMetadata/copyright')).to be_nil
      expect(doc.at_xpath('/rightsMetadata/copyright/human[@type="copyright"]')).to be_nil
    end

    it 'assigns blank copyright' do
      @apo.copyright_statement = ' '
      expect(@apo.copyright_statement).to be_nil
    end

    it 'errors if assigning copyright after removing one' do
      @apo.copyright_statement = nil
      @apo.copyright_statement = nil # call twice to ensure repeatability
      expect { @apo.copyright_statement = 'will fail' }.not_to raise_error
    end
  end

  describe 'metadata_source' do
    it 'gets the metadata source' do
      expect(@apo.metadata_source).to eq('MDToolkit')
    end

    it 'gets nil for an empty datastream' do
      expect(@empty_item.metadata_source).to eq(nil)
    end
  end

  describe 'metadata_source=' do
    it 'sets the metadata source' do
      @apo.metadata_source = 'Symphony'
      expect(@apo.metadata_source).to eq('Symphony')
      expect(@apo.administrativeMetadata).to be_changed
    end

    it 'sets the metadata source for an empty datastream' do
      @empty_item.desc_metadata_format = 'TEI'
      @empty_item.metadata_source = 'Symphony'
      expect(@empty_item.metadata_source).to eq('Symphony')
    end
  end

  describe 'creative_commons_license' do
    it 'finds the creative commons license' do
      expect(@apo.creative_commons_license).to eq('by-nc-sa')
    end

    it 'does not fail on an item with an empty datastream' do
      expect(@empty_item.creative_commons_license).to eq('')
    end
  end

  describe 'creative_commons_human' do
    it 'finds the human readable cc license' do
      expect(@apo.creative_commons_license_human).to eq('CC Attribution-NonCommercial-ShareAlike 3.0')
    end
  end

  describe 'creative_commons_license=' do
    # these are less relevant now that we're moving to use_license= and away from setting individual use license components so directly
    it 'works on an empty ds' do
      @empty_item.creative_commons_license = 'by-nc'
      expect(@empty_item.creative_commons_license).to eq('by-nc')
    end

    it 'does not create multiple use nodes' do
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
    it 'sets the human readable cc license' do
      @apo.creative_commons_license_human = 'greetings'
      expect(@apo.creative_commons_license_human).to eq('greetings')
    end

    it 'works on an empty ds' do
      @empty_item.creative_commons_license_human = 'greetings'
      expect(@empty_item.creative_commons_license_human).to eq('greetings')
    end
  end

  describe 'use_license=' do
    it 'sets the machine and human readable CC licenses given the right license code' do
      use_license_machine = 'by-nc-nd'
      use_license = Dor::CreativeCommonsLicenseService.property(use_license_machine)
      @empty_item.use_license = use_license_machine
      expect(@empty_item.use_license).to eq use_license_machine
      expect(@empty_item.use_license_uri).to eq use_license.uri
      expect(@empty_item.use_license_human).to eq use_license.label
      expect(@empty_item.creative_commons_license).to eq use_license_machine
      expect(@empty_item.creative_commons_license_human).to eq use_license.label
      expect(@empty_item.open_data_commons_license).to eq ''
      expect(@empty_item.open_data_commons_license_human).to eq ''
    end

    it 'sets the machine and human readable ODC licenses given the right license code' do
      use_license_machine = 'odc-by'
      use_license = Dor::OpenDataLicenseService.property(use_license_machine)
      @empty_item.use_license = use_license_machine
      expect(@empty_item.use_license).to eq use_license_machine
      expect(@empty_item.use_license_human).to eq use_license.label
      expect(@empty_item.creative_commons_license).to eq ''
      expect(@empty_item.creative_commons_license_human).to eq ''
      expect(@empty_item.open_data_commons_license).to eq use_license_machine
      expect(@empty_item.open_data_commons_license_human).to eq use_license.label
    end

    it 'throws an exception if no valid license code is given' do
      expect { @empty_item.use_license = 'something-unexpected' }.to raise_exception(ArgumentError)
      expect(@empty_item.use_license).to be_blank
      expect(@empty_item.use_license_human).to be_blank
    end

    it 'is able to remove the use license' do
      [:none, '  ', nil].each do |v|
        @apo.use_license = v
        expect(@apo.use_license).to be_blank
        expect(@apo.use_license_uri).to be_nil
        expect(@apo.use_license_human).to be_blank
        expect(@apo.creative_commons_license).to be_nil
        expect(@apo.creative_commons_license_human).to be_nil
        expect(@apo.open_data_commons_license).to be_nil
        expect(@apo.open_data_commons_license_human).to be_nil
      end
    end
  end

  describe '#default_rights' do
    it 'finds the default object rights' do
      expect(@apo.default_rights).to eq('world')
    end

    it 'uses the OM template if the ds is empty' do
      expect(@empty_item.default_rights).to eq('world')
    end
  end

  describe '#default_rights=' do
    it 'sets default rights' do
      @apo.default_rights = 'stanford'
      expect(@apo.default_rights).to eq('stanford')
    end

    it 'works on an empty ds' do
      @empty_item.default_rights = 'stanford'
      expect(@empty_item.default_rights).to eq('stanford')
    end
  end

  describe 'desc metadata format' do
    it 'finds the desc metadata format' do
      expect(@apo.desc_metadata_format).to eq('MODS')
    end

    it 'does not fail on an item with an empty datastream' do
      expect(@empty_item.desc_metadata_format).to eq(nil)
    end

    it 'sets dark correctly' do
      @apo.default_rights = 'dark'
      expect(@apo.default_rights).to eq('dark')
    end

    it 'setters should be case insensitive' do
      @apo.default_rights = 'Dark'
      expect(@apo.default_rights).to eq('dark')
    end

    it 'sets read rights to none for dark' do
      @apo.default_rights = 'Dark'
      xml = @apo.datastreams['defaultObjectRights'].ng_xml
      expect(xml.search('//rightsMetadata/access[@type=\'read\']/machine/none').length).to eq(1)
    end
  end

  describe 'desc_metadata_format=' do
    it 'sets the desc metadata format' do
      @apo.desc_metadata_format = 'TEI'
      expect(@apo.desc_metadata_format).to eq('TEI')
    end

    it 'sets the desc metadata format for an empty datastream' do
      @empty_item.desc_metadata_format = 'TEI'
      expect(@empty_item.desc_metadata_format).to eq('TEI')
    end
  end

  describe 'mods_title' do
    it 'gets the title' do
      expect(@apo.mods_title).to eq('Ampex')
    end

    it 'does not fail on an item with an empty datastream' do
      expect(@empty_item.mods_title).to eq('')
    end
  end

  describe 'mods_title=' do
    it 'sets the title' do
      @apo.mods_title = 'hello world'
      expect(@apo.mods_title).to eq('hello world')
    end

    it 'works on an empty datastream' do
      @empty_item.mods_title = 'hello world'
      expect(@empty_item.mods_title).to eq('hello world')
    end
  end

  describe 'default workflows' do
    it 'finds the default workflows' do
      expect(@apo.default_workflows).to eq(['digitizationWF'])
    end

    it 'is able to set default workflows' do
      @apo.default_workflow = 'accessionWF'
      expect(@apo.default_workflows).to eq(['accessionWF'])
    end

    it 'is not able to set a null default workflows' do
      expect { @apo.default_workflow = '' }.to raise_error(ArgumentError)
      expect(@apo.default_workflows).to eq(['digitizationWF']) # the original default workflow
    end
  end

  describe 'copyright_statement=' do
    it 'assigns' do
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
    it 'assigns' do
      skip 'dispatches "belongs_to" association for agreement_object down into internals of ActiveFedora'
    end
  end

  describe 'default_workflow=' do
    it 'sets the default workflow' do
      @apo.default_workflow = 'thisWF'
      expect(@apo.default_workflows).to include('thisWF')
    end

    it 'works on an empty ds' do
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
end
