# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::EmbargoMetadataDS do
  before do
    @ds = described_class.new nil, 'embargoMetadata'
  end

  context 'Marshalling to and from a Fedora Datastream' do
    let(:dsxml) do
      <<-EOF
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
      EOF
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
      emb_xml = <<-EOF
      <embargoMetadata>
        <status/>
        <releaseDate/>
        <releaseAccess/>
        <twentyPctVisibilityStatus/>
        <twentyPctVisibilityReleaseDate/>
      </embargoMetadata>
      EOF
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
    before do
      @t = Time.now.utc - 10
      @ds.release_date = @t
    end

    it '= sets releaseDate from a Time object' do
      # does NOT do beginning_of_day truncation, leave that for indexing
      rd = Time.parse(@ds.term_values(:release_date).first)
      expect(rd.strftime('%FT%T%z')).to eq(@t.strftime('%FT%T%z')) # not strictly equal since "now" has millesecond granularity
    end

    it '= marks the datastram as changed' do
      expect(@ds).to be_changed
    end

    it 'gets the current value of releaseDate as a Time object' do
      rd = @ds.release_date
      expect(rd).to be_a(Time)
      expect(rd).to be < Time.now.utc
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
