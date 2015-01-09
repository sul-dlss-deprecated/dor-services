require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'
require 'equivalent-xml'
require 'dor/datastreams/desc_metadata_ds'

describe Dor::DescMetadataDS do
  context "Marshalling to and from a Fedora Datastream" do
    before(:each) do
      @dsxml =<<-EOF
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
      
      @dsdoc = Dor::DescMetadataDS.from_xml(@dsxml)
    end
    
    it "should get correct values from OM terminology" do
      expect(@dsdoc.term_values(:abstract)).to eq(['Abstract contents.'])
    end

  end
    
end
