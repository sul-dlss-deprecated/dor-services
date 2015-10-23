require 'spec_helper'

describe Dor::DescMetadataDS do
  before :each do
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
      </mods>
    EOF
  end

  it 'should get correct values from OM terminology' do
    expect(@dsdoc.term_values(:abstract)).to eq ['Abstract contents.']
    expect(@dsdoc.abstract).to eq ['Abstract contents.']
    expect(@dsdoc.title_info.main_title).to eq ['Electronic Theses and Dissertations']
    expect(@dsdoc.language.languageTerm).to eq ['eng']
  end
  it 'writing elements via OM terms should produce correct XML' do
    @partial.language.languageTerm = 'eng'
    @partial.abstract = 'Abstract contents.'
    expect(@partial.to_xml).to be_equivalent_to(@dsdoc.to_xml)
  end

end
