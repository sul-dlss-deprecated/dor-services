require 'spec_helper'

class RightsHaver < Dor::Item
  # include Dor::Rightsable
end

describe Dor::RightsMetadataDS do
  before(:each) { stub_config }
  after(:each)  { unstub_config }

  before(:each) do
    @item = instantiate_fixture('druid:bb046xn0881', RightsHaver)
    # allow(@item).to receive(:new?).and_return(false)
    allow(@item).to receive(:workflows).and_return(double())
    allow(Dor::Item).to receive(:find).with('druid:bb046xn0881').and_return(@item)
    allow(Dor::WorkflowService).to receive(:get_milestones).and_return([])
  end

  it '#new' do
    expect(Dor::RightsMetadataDS.new).to be_a(Dor::RightsMetadataDS)
  end

  it 'should have a rightsMetadata datastream accessible' do
    expect(@item).to be_a(RightsHaver)
    expect(@item).to be_kind_of(Dor::Item)
    expect(@item.datastreams['rightsMetadata']).to be_a(Dor::RightsMetadataDS)
    expect(@item.rightsMetadata).to eq(@item.datastreams['rightsMetadata'])
  end

  describe 'rightsMetadata' do
    before :each do
      @rm = @item.datastreams['rightsMetadata']
    end
    it 'has accessors from defined terminology' do
      expect(@rm.copyright  ).to eq ['Courtesy of the Revs Institute for Automotive Research. All rights reserved unless otherwise indicated.']
      ## use.human differs from use_statement: the former hits two elements (one unpopulated), the latter only one
      expect(@rm.use.human    ).to eq ['Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.', '']
      expect(@rm.use_statement).to eq ['Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.']
      expect(@rm.use.machine     ).to eq ['']
      expect(@rm.creative_commons).to eq ['']
      # The following tests fail if terminology defined with :type instead of :path => '/x/y[@type=...]'
      expect(@rm.creative_commons_human).not_to include 'Users must contact the The Revs Institute for Automotive Research for re-use and reproduction information.'
      expect(@rm.creative_commons_human).to eq ['']
    end
    it 'has a Dor::RightsAuth dra_object' do
      expect(@rm.dra_object).to be_a(Dor::RightsAuth)
      expect(@rm.dra_object.index_elements).to match a_hash_including(:primary => 'stanford', :errors => [])
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
        'rights_primary_ssi'  => 'stanford',
        'metadata_source_ssi' => 'DOR',
        'title_tesim'         => ['Indianapolis 500'],
        'rights_characteristics_ssim' => ['world_discover', 'has_group_rights', 'has_rule', 'group|stanford', 'world|no-download', 'profile:group1|world1']
      )
      expect(doc).not_to include('rights_errors_ssim')  # don't include empties
    end
  end
end
