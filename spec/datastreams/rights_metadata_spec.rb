# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::RightsMetadataDS do
  it '#new' do
    expect { described_class.new }.not_to raise_error
  end

  describe '#embargo_release_date' do
    subject(:embargo_release_date) { ds.embargo_release_date }

    let(:ds) { described_class.new }
    let(:time) { DateTime.parse('2039-10-30T12:22:33Z') }

    before do
      ds.embargo_release_date = time
    end

    it { is_expected.to eq [time] }
  end

  describe 'upd_rights_xml_for_rights_type' do
    let(:original_rights_xml) do
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
    end

    let(:world_rights_xml) do
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
    end
    let(:world_no_download_rights_xml) do
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
    end
    let(:stanford_rights_xml) do
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
    end
    let(:stanford_no_download_rights_xml) do
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
    end
    let(:loc_spec_rights_xml) do
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
    end
    let(:dark_rights_xml) do
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
    end
    let(:citation_only_rights_xml) do
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
    end
    let(:loc_unsupported_rights_xml) do
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
    end
    let(:cdl_no_download_rights_xml) do
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
              <cdl>
                <group rule="no-download">stanford</group>
              </cdl>
            </machine>
          </access>
          <use>
            <human type="useAndReproduction">Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.</human>
            <human type="creativeCommons">Attribution Non-Commercial 3.0 Unported</human>
            <machine type="creativeCommons">by-nc</machine>
          </use>
        </rightsMetadata>
      XML
    end

    it 'has the expected rights xml when read rights are set to world' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      described_class.upd_rights_xml_for_rights_type(rights_ng_xml, 'world')
      expect(rights_ng_xml).to be_equivalent_to world_rights_xml
    end

    it 'has the expected rights xml when read rights are set to world with the no-download rule' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      described_class.upd_rights_xml_for_rights_type(rights_ng_xml, 'world-nd')
      expect(rights_ng_xml).to be_equivalent_to world_no_download_rights_xml
    end

    it 'has the expected rights xml when read rights are set to group stanford' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      described_class.upd_rights_xml_for_rights_type(rights_ng_xml, 'stanford')
      expect(rights_ng_xml).to be_equivalent_to stanford_rights_xml
    end

    it 'has the expected rights xml when read rights are set to group stanford with the no-download rule' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      described_class.upd_rights_xml_for_rights_type(rights_ng_xml, 'stanford-nd')
      expect(rights_ng_xml).to be_equivalent_to stanford_no_download_rights_xml
    end

    it 'has the expected rights xml when read rights are set to controlled digital lending with the no-download rule' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      described_class.upd_rights_xml_for_rights_type(rights_ng_xml, 'cdl-stanford-nd')
      expect(rights_ng_xml).to be_equivalent_to cdl_no_download_rights_xml
    end

    it 'has the expected rights xml when read rights are set to location spec' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      described_class.upd_rights_xml_for_rights_type(rights_ng_xml, 'loc:spec')
      expect(rights_ng_xml).to be_equivalent_to loc_spec_rights_xml
    end

    it 'has the expected rights xml when read rights are set to dark' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      described_class.upd_rights_xml_for_rights_type(rights_ng_xml, 'dark')
      expect(rights_ng_xml).to be_equivalent_to dark_rights_xml
    end

    it 'has the expected rights xml when read rights are set to citation only' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      described_class.upd_rights_xml_for_rights_type(rights_ng_xml, 'none')
      expect(rights_ng_xml).to be_equivalent_to citation_only_rights_xml
    end

    it 'will set an unrecognized location, because it is not where rights type code is validated' do
      rights_ng_xml = Nokogiri::XML(original_rights_xml)
      described_class.upd_rights_xml_for_rights_type(rights_ng_xml, 'loc:unsupported')
      expect(rights_ng_xml).to be_equivalent_to loc_unsupported_rights_xml
    end
  end

  describe 'rights' do
    let(:rights_md) do
      # this fixture has world read rights by default
      instantiate_fixture('druid:cg767mn6478', Dor::Item).rightsMetadata
    end

    it 'indicates the rights as world' do
      expect(rights_md.rights).to eq 'World'
    end

    it 'indicates the rights as None for controlled digital lending (which will have a separate attribute to indicate it is cdl)' do
      rights_md.set_read_rights 'cdl-stanford-nd'
      expect(rights_md.rights).to eq 'None'
    end

    it 'indicates the rights as stanford' do
      rights_md.set_read_rights 'stanford'
      expect(rights_md.rights).to eq 'Stanford'
    end

    it 'indicates the rights as dark' do
      rights_md.set_read_rights 'dark'
      expect(rights_md.rights).to eq 'Dark'
    end
  end

  describe 'set_read_rights' do
    let(:rights_md) do
      instantiate_fixture('druid:bb046xn0881', Dor::Item).rightsMetadata
    end

    it 'will raise an exception when an unsupported rights type is given' do
      expect { rights_md.set_read_rights 'loc:unsupported' }.to raise_error ArgumentError, "Argument 'loc:unsupported' is not a recognized value"
    end

    it 'will set the xml properly and indicate that datastream content has changed' do
      expect(described_class).to receive(:upd_rights_xml_for_rights_type).with(rights_md.ng_xml, 'world')
      expect(rights_md).to receive(:ng_xml_will_change!).and_call_original

      rights_md.set_read_rights 'world'
      expect(rights_md.instance_variable_get(:@dra_object)).to be_nil
    end
  end

  describe 'rightsMetadata' do
    let(:rights_md) do
      instantiate_fixture('druid:bb046xn0881', Dor::Item).rightsMetadata
    end

    it 'has accessors from defined terminology' do
      expect(rights_md.copyright).to eq ['Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.']
      expect(rights_md.use_statement).to eq ['Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.']
      expect(rights_md.use_license).to eq ['by-nc']
      ## use.human differs from use_statement: the former hits multiple elements, the latter only one
      expect(rights_md.use.human).to eq ['Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.', 'Attribution Non-Commercial 3.0 Unported']
    end

    it 'has a Dor::RightsAuth dra_object' do
      expect(rights_md.dra_object).to be_a(Dor::RightsAuth)
      expect(rights_md.dra_object.index_elements).to match a_hash_including(primary: 'world_qualified', errors: [])
    end

    it 'reads creative commons licenses correctly' do
      expect(rights_md.creative_commons).to eq ['by-nc']
      # The following tests fail if terminology defined with :type instead of :path => '/x/y[@type=...]'
      expect(rights_md.creative_commons_human).not_to include 'Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.'
      expect(rights_md.creative_commons_human).to eq ['Attribution Non-Commercial 3.0 Unported']
    end

    it 'does not test open data commons licenses' do
      skip
    end
  end
end
