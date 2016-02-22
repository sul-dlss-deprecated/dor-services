require 'spec_helper'

describe Dor::RightsMetadataDS do
  before(:each) { stub_config }
  after(:each)  { unstub_config }

  before(:each) do
    @item = instantiate_fixture('druid:bb046xn0881', Dor::Item)
    allow(Dor::Item).to receive(:find).with(@item.pid).and_return(@item)
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
        'rights_primary_ssi'  => 'world_qualified',
        'metadata_source_ssi' => 'DOR',
        'title_tesim'         => ['Indianapolis 500'],
        'rights_characteristics_ssim' => include(
          'world_discover', 'has_group_rights', 'has_rule', 'group|stanford', 'world_read', 'world|no-download', 'profile:group1|world1'
        ),
        'use_license_machine_ssi'     => 'by-nc'
      )
      expect(doc).not_to include('rights_errors_ssim')  # don't include empties
    end
  end
end
