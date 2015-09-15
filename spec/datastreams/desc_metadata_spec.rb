require 'spec_helper'

describe Dor::DescMetadataDS do
  context 'Marshalling to/from a Fedora Datastream' do
    before(:each) do
      @dsxml = <<-EOF
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

      @dsdoc = Dor::DescMetadataDS.from_xml(@dsxml)
    end

    it 'should get correct values from OM terminology' do
      expect(@dsdoc.term_values(:abstract)).to eq(['Abstract contents.'])
      expect(@dsdoc.abstract              ).to eq(['Abstract contents.'])  # equivalent accessor
      expect(@dsdoc.subject.geographic).to eq(['First Place', 'Other Place, Nation;'])
      expect(@dsdoc.subject.temporal  ).to eq(['1890-1910', '20th century', 'another'])
      expect(@dsdoc.subject.topic     ).to eq(['Topic1: Boring Part', 'Topic2: The Interesting Part!'])
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
  end

end
