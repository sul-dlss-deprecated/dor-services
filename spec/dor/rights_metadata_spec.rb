require 'spec_helper'

describe Dor::RightsMetadataDS do
  before(:each) { stub_config }
  after(:each)  { unstub_config }

  before(:each) do
    @item = instantiate_fixture('druid:bb046xn0881', Dor::Item)
    allow(Dor).to receive(:find).with(@item.pid).and_return(@item)
    allow(@item).to receive(:workflows).and_return(double)
    allow(Dor::Config.workflow.client).to receive(:get_milestones).and_return([])
  end

  it '#new' do
    expect { Dor::RightsMetadataDS.new }.not_to raise_error
  end

  it 'should have a rightsMetadata datastream accessible' do
    expect(@item.datastreams['rightsMetadata']).to be_a(Dor::RightsMetadataDS)
    expect(@item.rightsMetadata).to eq(@item.datastreams['rightsMetadata'])
  end

  describe 'upd_rights_xml_for_rights_type' do
    let(:original_rights_xml) {
      <<-XML
        <rightsMetadata>
          <copyright>
            <human type="copyright">Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.</human>
          </copyright>
          <access type="discover">
            <machine>
              <world></world>
            </machine>
          </access>
          <access type="read">
            <machine>
              <group>stanford</group>
              <world rule="no-download"></world>
              <location rule="no-download">reading_room</location>
            </machine>
          </access>
          <use>
            <human type="useAndReproduction">Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.</human>
            <human type="creativeCommons">Attribution Non-Commercial 3.0 Unported</human>
            <machine type="creativeCommons">by-nc</machine>
          </use>
        </rightsMetadata>
      XML
    }

    let(:world_rights_xml) {
      <<-XML
        <rightsMetadata>
          <copyright>
            <human type="copyright">Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.</human>
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
            <human type="useAndReproduction">Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.</human>
            <human type="creativeCommons">Attribution Non-Commercial 3.0 Unported</human>
            <machine type="creativeCommons">by-nc</machine>
          </use>
        </rightsMetadata>
      XML
    }
    let(:world_no_download_rights_xml) {
      <<-XML
        <rightsMetadata>
          <copyright>
            <human type="copyright">Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.</human>
          </copyright>
          <access type="discover">
            <machine>
              <world/>
            </machine>
          </access>
          <access type="read">
            <machine>
              <world rule="no-download"/>
            </machine>
          </access>
          <use>
            <human type="useAndReproduction">Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.</human>
            <human type="creativeCommons">Attribution Non-Commercial 3.0 Unported</human>
            <machine type="creativeCommons">by-nc</machine>
          </use>
        </rightsMetadata>
      XML
    }
    let(:stanford_rights_xml) {
      <<-XML
        <rightsMetadata>
          <copyright>
            <human type="copyright">Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.</human>
          </copyright>
          <access type="discover">
            <machine>
              <world/>
            </machine>
          </access>
          <access type="read">
            <machine>
              <group>stanford</group>
            </machine>
          </access>
          <use>
            <human type="useAndReproduction">Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.</human>
            <human type="creativeCommons">Attribution Non-Commercial 3.0 Unported</human>
            <machine type="creativeCommons">by-nc</machine>
          </use>
        </rightsMetadata>
      XML
    }
    let(:stanford_no_download_rights_xml) {
      <<-XML
        <rightsMetadata>
          <copyright>
            <human type="copyright">Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.</human>
          </copyright>
          <access type="discover">
            <machine>
              <world/>
            </machine>
          </access>
          <access type="read">
            <machine>
              <group rule="no-download">stanford</group>
            </machine>
          </access>
          <use>
            <human type="useAndReproduction">Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.</human>
            <human type="creativeCommons">Attribution Non-Commercial 3.0 Unported</human>
            <machine type="creativeCommons">by-nc</machine>
          </use>
        </rightsMetadata>
      XML
    }
    let(:loc_spec_rights_xml) {
      <<-XML
        <rightsMetadata>
          <copyright>
            <human type="copyright">Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.</human>
          </copyright>
          <access type="discover">
            <machine>
              <world/>
            </machine>
          </access>
          <access type="read">
            <machine>
              <location>spec</group>
            </machine>
          </access>
          <use>
            <human type="useAndReproduction">Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.</human>
            <human type="creativeCommons">Attribution Non-Commercial 3.0 Unported</human>
            <machine type="creativeCommons">by-nc</machine>
          </use>
        </rightsMetadata>
      XML
    }
    let(:dark_rights_xml) {
      <<-XML
        <rightsMetadata>
          <copyright>
            <human type="copyright">Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.</human>
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
            <human type="useAndReproduction">Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.</human>
            <human type="creativeCommons">Attribution Non-Commercial 3.0 Unported</human>
            <machine type="creativeCommons">by-nc</machine>
          </use>
        </rightsMetadata>
      XML
    }
    let(:citation_only_rights_xml) {
      <<-XML
        <rightsMetadata>
          <copyright>
            <human type="copyright">Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.</human>
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
            <human type="useAndReproduction">Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.</human>
            <human type="creativeCommons">Attribution Non-Commercial 3.0 Unported</human>
            <machine type="creativeCommons">by-nc</machine>
          </use>
        </rightsMetadata>
      XML
    }
    let(:loc_unsupported_rights_xml) {
      <<-XML
        <rightsMetadata>
          <copyright>
            <human type="copyright">Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.</human>
          </copyright>
          <access type="discover">
            <machine>
              <world/>
            </machine>
          </access>
          <access type="read">
            <machine>
              <location>unsupported</group>
            </machine>
          </access>
          <use>
            <human type="useAndReproduction">Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.</human>
            <human type="creativeCommons">Attribution Non-Commercial 3.0 Unported</human>
            <machine type="creativeCommons">by-nc</machine>
          </use>
        </rightsMetadata>
      XML
    }

    it 'has the expected rights xml when read rights are set to world' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      Dor::RightsMetadataDS.upd_rights_xml_for_rights_type(rights_ng_xml, 'world')
      expect(rights_ng_xml).to be_equivalent_to world_rights_xml
    end

    it 'has the expected rights xml when read rights are set to world with the no-download rule' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      Dor::RightsMetadataDS.upd_rights_xml_for_rights_type(rights_ng_xml, 'world-nd')
      expect(rights_ng_xml).to be_equivalent_to world_no_download_rights_xml
    end

    it 'has the expected rights xml when read rights are set to group stanford' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      Dor::RightsMetadataDS.upd_rights_xml_for_rights_type(rights_ng_xml, 'stanford')
      expect(rights_ng_xml).to be_equivalent_to stanford_rights_xml
    end

    it 'has the expected rights xml when read rights are set to group stanford with the no-download rule' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      Dor::RightsMetadataDS.upd_rights_xml_for_rights_type(rights_ng_xml, 'stanford-nd')
      expect(rights_ng_xml).to be_equivalent_to stanford_no_download_rights_xml
    end

    it 'has the expected rights xml when read rights are set to location spec' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      Dor::RightsMetadataDS.upd_rights_xml_for_rights_type(rights_ng_xml, 'loc:spec')
      expect(rights_ng_xml).to be_equivalent_to loc_spec_rights_xml
    end

    it 'has the expected rights xml when read rights are set to dark' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      Dor::RightsMetadataDS.upd_rights_xml_for_rights_type(rights_ng_xml, 'dark')
      expect(rights_ng_xml).to be_equivalent_to dark_rights_xml
    end

    it 'has the expected rights xml when read rights are set to citation only' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      Dor::RightsMetadataDS.upd_rights_xml_for_rights_type(rights_ng_xml, 'none')
      expect(rights_ng_xml).to be_equivalent_to citation_only_rights_xml
    end

    it 'will set an unrecognized location, because it is not where rights type code is validated' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      Dor::RightsMetadataDS.upd_rights_xml_for_rights_type(rights_ng_xml, 'loc:unsupported')
      expect(rights_ng_xml).to be_equivalent_to loc_unsupported_rights_xml
    end
  end

  describe 'set_read_rights' do
    it 'will raise an exception when an unsupported rights type is given' do
      expect { @item.rightsMetadata.set_read_rights 'loc:unsupported' }.to raise_error ArgumentError, "Argument 'loc:unsupported' is not a recognized value"
    end

    it 'will set the xml properly and indicate that datastream content has changed' do
      expect(Dor::RightsMetadataDS).to receive(:upd_rights_xml_for_rights_type).with(@item.rightsMetadata.ng_xml, 'world')
      expect(@item.rightsMetadata).to receive(:dra_object=).with(nil).and_call_original
      expect(@item.rightsMetadata).to receive(:ng_xml_will_change!).and_call_original

      @item.rightsMetadata.set_read_rights 'world'
    end
  end

  describe 'rightsMetadata' do
    before :each do
      @rm = @item.rightsMetadata
    end
    it 'has accessors from defined terminology' do
      expect(@rm.copyright).to eq ['Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.']
      expect(@rm.use_statement).to eq ['Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.']
      expect(@rm.use_license).to eq ['by-nc']
      ## use.human differs from use_statement: the former hits multiple elements, the latter only one
      expect(@rm.use.human).to eq ['Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.', 'Attribution Non-Commercial 3.0 Unported']
    end
    it 'has a Dor::RightsAuth dra_object' do
      expect(@rm.dra_object).to be_a(Dor::RightsAuth)
      expect(@rm.dra_object.index_elements).to match a_hash_including(:primary => 'world_qualified', :errors => [])
    end
    it 'reads creative commons licenses correctly' do
      expect(@rm.creative_commons).to eq ['by-nc']
      # The following tests fail if terminology defined with :type instead of :path => '/x/y[@type=...]'
      expect(@rm.creative_commons_human).not_to include 'Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.'
      expect(@rm.creative_commons_human).to eq ['Attribution Non-Commercial 3.0 Unported']
    end
    it 'does not test open data commons licenses' do
      skip
    end
  end

  describe 'to_solr' do
    before :each do
      allow(OpenURI).to receive(:open_uri).with('https://purl-test.stanford.edu/bb046xn0881.xml').and_return('<xml/>')
    end

    it 'should have correct primary' do
      expect(Dor.logger).to receive(:warn).with(/Cannot index druid:bb046xn0881\.descMetadata/)
      doc = @item.to_solr

      expect(doc).to match a_hash_including(
        'rights_primary_ssi'          => 'world_qualified',
        'rights_descriptions_ssim'    => include(
          'location: reading_room (no-download)', 'stanford', 'world (no-download)', 'dark (file)'
        ),
        'metadata_source_ssi'         => 'DOR',
        'title_tesim'                 => ['Indianapolis 500'],
        'rights_characteristics_ssim' => include(
          'world_discover', 'has_group_rights', 'has_rule', 'group|stanford', 'location', 'location_with_rule',
          'world_read', 'world|no-download', 'profile:group1|location1|world1', 'none_read_file'
        ),
        'use_license_machine_ssi'     => 'by-nc',
        'obj_rights_locations_ssim'   => ['reading_room']
      )
      expect(doc).not_to include(
        'rights_errors_ssim', 'file_rights_locations_ssim', 'obj_rights_agents_ssim', 'file_rights_agents_ssim'
      )  # don't include empties
    end

    it 'should filter access_restricted from what gets aggregated into rights_descriptions_ssim' do
      rights_md_ds = Dor::RightsMetadataDS.new
      mock_dra_obj = double(Dor::RightsAuth)
      expect(mock_dra_obj).to receive(:index_elements).with(no_args).at_least(:once).and_return(
        :primary => 'access_restricted',
        :errors  => [],
        :terms   => [],
        :obj_locations_qualified => [{:location => 'someplace', :rule => 'somerule'}],
        :file_groups_qualified   => [{:group => 'somegroup', :rule => 'someotherrule'}]
      )
      expect(rights_md_ds).to receive(:dra_object).and_return(mock_dra_obj)

      doc = rights_md_ds.to_solr
      expect(doc).to match a_hash_including(
        'rights_primary_ssi'       => 'access_restricted',
        'rights_descriptions_ssim' => include('location: someplace (somerule)', 'somegroup (file) (someotherrule)'),
      )
      expect(doc).not_to match a_hash_including(
        'rights_descriptions_ssim' => include('access_restricted')
      )
    end

    it 'should filter world_qualified from what gets aggregated into rights_descriptions_ssim' do
      rights_md_ds = Dor::RightsMetadataDS.new
      mock_dra_obj = double(Dor::RightsAuth)
      expect(mock_dra_obj).to receive(:index_elements).with(no_args).at_least(:once).and_return(
        :primary => 'world_qualified',
        :errors  => [],
        :terms   => [],
        :obj_world_qualified => [{:rule => 'somerule'}]
      )
      expect(rights_md_ds).to receive(:dra_object).and_return(mock_dra_obj)

      doc = rights_md_ds.to_solr
      expect(doc).to match a_hash_including(
        'rights_primary_ssi'       => 'world_qualified',
        'rights_descriptions_ssim' => include('world (somerule)'),
      )
      expect(doc).not_to match a_hash_including(
        'rights_descriptions_ssim' => include('world_qualified')
      )
    end

    it 'should include the simple fields that are present' do
      rights_md_ds = Dor::RightsMetadataDS.new
      mock_dra_obj = double(Dor::RightsAuth)
      expect(mock_dra_obj).to receive(:index_elements).with(no_args).at_least(:once).and_return(
        :primary => 'access_restricted',
        :errors  => [],
        :terms   => [],
        :obj_locations  => ['location'],
        :file_locations => ['file_specific_location'],
        :obj_agents     => ['agent'],
        :file_agents    => ['file_specific_agent']
      )
      expect(rights_md_ds).to receive(:dra_object).and_return(mock_dra_obj)

      doc = rights_md_ds.to_solr
      expect(doc).to match a_hash_including(
        'obj_rights_locations_ssim'  => ['location'],
        'file_rights_locations_ssim' => ['file_specific_location'],
        'obj_rights_agents_ssim'     => ['agent'],
        'file_rights_agents_ssim'    => ['file_specific_agent']
      )
    end
  end
end
