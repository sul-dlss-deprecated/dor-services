# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::EmbargoMetadataDS do
  before do
    @ds = described_class.new nil, 'embargoMetadata'
  end

  context 'Marshalling to and from a Fedora Datastream' do
    let(:dsxml) do
      <<-XML
          <embargoMetadata>
            <status>embargoed</status>
            <releaseDate>2011-10-12T15:47:52-07:00</releaseDate>
            <twentyPctVisibilityStatus>released</twentyPctVisibilityStatus>
            <twentyPctVisibilityReleaseDate>2016-10-12T15:47:52-07:00</twentyPctVisibilityReleaseDate>
            <releaseAccess>
              <access type="discover">
                <machine>
                  <world />
                </machine>
              </access>
              <access type="read">
                <machine>
                  <world />
                </machine>
              </access>
            </releaseAccess>
          </embargoMetadata>
      XML
    end

    it 'creates itself from xml' do
      ds = described_class.from_xml(dsxml)
      expect(ds.term_values(:status)).to eq(['embargoed'])
      expect(ds.term_values(:release_date)).to eq(['2011-10-12T15:47:52-07:00'])
      expect(ds.term_values(:twenty_pct_status)).to eq(['released'])
      expect(ds.term_values(:twenty_pct_release_date)).to eq(['2016-10-12T15:47:52-07:00'])
      expect(ds.find_by_terms(:release_access)).to be_a(Nokogiri::XML::NodeSet)
    end

    it 'creates a simple default with #new' do
      emb_xml = <<-XML
      <embargoMetadata>
        <status/>
        <releaseDate/>
        <releaseAccess/>
        <twentyPctVisibilityStatus/>
        <twentyPctVisibilityReleaseDate/>
      </embargoMetadata>
      XML
      expect(@ds.to_xml).to be_equivalent_to(emb_xml)
    end

    it 'solrizes correctly' do
      ds = described_class.from_xml(dsxml)
      release_date_field = Solrizer.solr_name('embargo_release', :dateable)
      twenty_pct_field   = Solrizer.solr_name('twenty_pct_visibility_release', :dateable)
      expect(ds.to_solr).to match a_hash_including(release_date_field, twenty_pct_field)
      expect(ds.to_solr[release_date_field]).to eq ['2011-10-12T00:00:00Z'] # field removes time granularity -- for questionable reasons
      expect(ds.to_solr[twenty_pct_field]).to eq ['2016-10-12T00:00:00Z'] # field removes time granularity -- for questionable reasons
    end
  end

  describe '#status' do
    before do
      @ds.status = 'released'
    end

    it '= sets status' do
      expect(@ds.term_values(:status)).to eq(['released'])
    end

    it '= marks the datastream as changed' do
      expect(@ds).to be_changed
    end

    it 'gets the current value of status' do
      expect(@ds.status).to eq('released')
    end
  end

  describe '#release_date' do
    subject { ds.release_date }

    let(:ds) { described_class.new }
    let(:time) { DateTime.parse('2039-10-30T12:22:33Z') }

    before do
      ds.release_date = time
    end

    it { is_expected.to eq [time] }

    it '= marks the datastram as changed' do
      expect(ds).to be_changed
    end
  end

  describe '#to_solr' do
    it 'copes with empty releaseDate' do
      empty_rel_date_xml =
        <<-XML
          <embargoMetadata>
            <status/>
            <releaseDate/>
            <releaseAccess/>
            <twentyPctVisibilityStatus/>
            <twentyPctVisibilityReleaseDate/>
          </embargoMetadata>
        XML
      ds = described_class.from_xml(empty_rel_date_xml)
      release_date_field = Solrizer.solr_name('embargo_release', :dateable)
      expect(ds.to_solr).not_to match a_hash_including(release_date_field)
    end

    it 'copes with missing releaseDate' do
      missing_rel_date_xml =
        <<-XML
          <embargoMetadata>
            <status/>
            <releaseAccess/>
            <twentyPctVisibilityStatus/>
            <twentyPctVisibilityReleaseDate/>
          </embargoMetadata>
        XML
      ds = described_class.from_xml(missing_rel_date_xml)
      release_date_field = Solrizer.solr_name('embargo_release', :dateable)
      expect(ds.to_solr).not_to match a_hash_including(release_date_field)
    end
  end

  describe 'releaseAccess manipulation' do
    it '#release_access_node returns a Nokogiri::XML::Element' do
      expect(@ds.release_access_node).to be_a(Nokogiri::XML::Element)
      expect(@ds.release_access_node.name).to eq('releaseAccess')
    end

    it 'release_access_node= refuses to set bogus value' do
      expect { @ds.release_access_node = Nokogiri::XML('<incorrect/>') }.to raise_error(RuntimeError)
    end

    it '#release_access_node= sets the embargoAccess node from a Nokogiri::XML::Node' do
      # delete old releaseAcess element and replace with this one
      embargo_xml = <<-EOXML
      <releaseAccess>
        <access type="discover">
          <machine>
            <world />
          </machine>
        </access>
        <access type="read">
          <machine>
            <world/>
          </machine>
        </access>
      </embargoAccess>
      EOXML
      @ds.release_access_node = Nokogiri::XML(embargo_xml)
      embargo = @ds.find_by_terms(:release_access)
      expect(embargo.at_xpath("//releaseAccess/access[@type='read']/machine/world")).to be
      expect(@ds).to be_changed
    end
  end

  describe 'use_and_reproduction_statement' do
    subject { ds.use_and_reproduction_statement }

    let(:ds) { described_class.new nil, 'embargoMetadata' }

    before do
      ds.use_and_reproduction_statement = 'These materials are in the public domain.'
    end

    it { is_expected.to eq ['These materials are in the public domain.'] }
  end
end
