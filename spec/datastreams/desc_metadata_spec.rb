# frozen_string_literal: true

require 'spec_helper'

describe Dor::DescMetadataDS do
  context 'Marshalling to/from a Fedora Datastream' do
    before(:each) do
      @dsdoc = Dor::DescMetadataDS.from_xml <<-EOF
        <mods xmlns="http://www.loc.gov/mods/v3"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3"
          xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
          <titleInfo>
            <title>Electronic Theses and Dissertations</title>
          </titleInfo>
          <abstract>Abstract contents.</abstract>
          <name type="corporate">
            <namePart>Stanford University Libraries, Stanford Digital Repository</namePart>
            <role>
              <roleTerm authority="marcrelator" type="text">creator</roleTerm>
            </role>
          </name>
          <typeOfResource collection="yes"/>
          <language>
            <languageTerm authority="iso639-2b" type="code">eng</languageTerm>
          </language>
          <subject>
            <geographic>First Place</geographic>
            <geographic>Other Place, Nation;</geographic>
            <temporal>1890-1910</temporal>
            <temporal>20th century</temporal>
            <topic>Topic1: Boring Part</topic>
          </subject>
          <subject><temporal>another</temporal></subject>
          <genre>first</genre>
          <genre>second</genre>
          <subject><topic>Topic2: The Interesting Part!</topic></subject>
        </mods>
      EOF
      @partial = Dor::DescMetadataDS.from_xml <<-EOF
        <mods xmlns="http://www.loc.gov/mods/v3"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3"
          xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
          <titleInfo>
            <title>Electronic Theses and Dissertations</title>
          </titleInfo>
          <name type="corporate">
            <namePart>Stanford University Libraries, Stanford Digital Repository</namePart>
            <role>
              <roleTerm authority="marcrelator" type="text">creator</roleTerm>
            </role>
          </name>
          <typeOfResource collection="yes"/>
          <subject>
            <geographic>First Place</geographic>
            <geographic>Other Place, Nation;</geographic>
            <temporal>1890-1910</temporal>
            <temporal>20th century</temporal>
            <topic>Topic1: Boring Part</topic>
          </subject>
          <subject><temporal>another</temporal></subject>
          <genre>first</genre>
          <genre>second</genre>
          <subject><topic>Topic2: The Interesting Part!</topic></subject>
        </mods>
      EOF
      @empty = Dor::DescMetadataDS.from_xml <<-EOF
        <mods xmlns:xlink="http://www.w3.org/1999/xlink"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns="http://www.loc.gov/mods/v3" version="3.3"
          xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
        </mods>
      EOF
    end

    it 'should get correct values from OM terminology' do
      expect(@dsdoc.term_values(:abstract)).to eq(['Abstract contents.'])
      expect(@dsdoc.abstract).to eq(['Abstract contents.']) # equivalent accessor
      expect(@dsdoc.subject.geographic).to eq(['First Place', 'Other Place, Nation;'])
      expect(@dsdoc.subject.temporal).to eq(['1890-1910', '20th century', 'another'])
      expect(@dsdoc.subject.topic).to eq(['Topic1: Boring Part', 'Topic2: The Interesting Part!'])
      expect(@dsdoc.title_info.main_title).to eq(['Electronic Theses and Dissertations'])
      expect(@dsdoc.language.languageTerm).to eq(['eng'])
    end

    it 'should solrize correctly' do
      doc = @dsdoc.to_solr
      expect(doc).to match a_hash_including('subject_temporal_tesim'   => ['1890-1910', '20th century', 'another'])
      expect(doc).to match a_hash_including('subject_topic_ssim'       => ['Topic1: Boring Part', 'Topic2: The Interesting Part!'])
      expect(doc).to match a_hash_including('subject_topic_tesim'      => ['Topic1: Boring Part', 'Topic2: The Interesting Part!'])
      expect(doc).to match a_hash_including('topic_ssim'               => ['Topic1: Boring Part', 'Topic2: The Interesting Part!'])
      expect(doc).to match a_hash_including('topic_tesim'              => ['Topic1: Boring Part', 'Topic2: The Interesting Part!'])
      expect(doc).to match a_hash_including('subject_geographic_ssim'  => ['First Place', 'Other Place, Nation;'])
      expect(doc).to match a_hash_including('subject_geographic_tesim' => ['First Place', 'Other Place, Nation;'])
      expect(doc).to match a_hash_including('abstract_tesim'           => ['Abstract contents.'])
    end
    it 'writing elements via OM terms should produce correct XML' do
      @partial.language.languageTerm = 'eng'
      @partial.abstract = 'Abstract contents.'
      expect(@partial.to_xml).to be_equivalent_to(@dsdoc.to_xml)
    end
    it 'should not throw an error when retrieving title_info if titleInfo is missing from the xml' do
      expect(@empty.title_info.main_title).to eq([])
    end
  end

  context 'Behavior of a freshly initialized Datastream' do
    it 'should not throw an error when retrieving title_info if the datastream object has yet to have XML content set' do
      desc_md_datastream = Dor::DescMetadataDS.new
      expect(desc_md_datastream.title_info.main_title).to eq([''])
    end

    it 'should use the expected MODS version' do
      desc_md_datastream = Dor::DescMetadataDS.new
      base_xpath = desc_md_datastream.ng_xml.at_xpath('/xmlns:mods', 'mods')
      expect(base_xpath.name).to eq 'mods'
      expect(base_xpath['version']).to eq '3.6'
      expect(base_xpath['xsi:schemaLocation']).to eq 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-6.xsd'
    end
  end
end
