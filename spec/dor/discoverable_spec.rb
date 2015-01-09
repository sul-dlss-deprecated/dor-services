require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'Dor::Discoverable' do
  before(:each) { stub_config   }
  after(:each)  { unstub_config }
  before :each do
    @item=instantiate_fixture("cj765pw7168", Dor::Item)
    allow(@item.descMetadata).to receive(:new?).and_return(false)
    allow(@item).to receive(:milestones).and_return({})
    allow(@item.descMetadata).to receive(:ng_xml).and_return(Nokogiri::XML('
    <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
      <titleInfo>
        <title>San Francisco, Cal.</title>
      </titleInfo>
      <titleInfo type="alternative">
        <title>San Francisco, circa 1900</title>
      </titleInfo>
      <name type="corporate">
        <namePart>Ghilion Beach, 107 Montgomery Street; Elliott Litho. Co., S. F.</namePart>
        <role>
          <roleTerm type="text">lithographer</roleTerm>
        </role>
      </name>
      <typeOfResource>still image</typeOfResource>
      <originInfo>
        <dateIssued>circa 1900</dateIssued>
      </originInfo>
      <physicalDescription>
        <form authority="aat">Graphics</form>
        <form>tinted lithograph on paper</form>
        <note displayLabel="Dimensions">19 x 38-1/4 inches</note>
        <note displayLabel="Condition">fair; deep soiled vertical center crease, two verticals at quarters, secondary creases</note>
      </physicalDescription>
      <abstract displayLabel="Description">
        Bird&#x2019;s eye view of the city with steam and sailing ships in the harbor and Golden Gate Park identified; including a key to 87 locations.
      </abstract>
      <identifier type="local">rd-115</identifier>
    </mods>
    
    '))
  end
  describe 'to_solr' do
    it 'should build a doc hash using stanford-mods' do
      doc_hash=@item.to_solr({})
      expect(doc_hash[:sw_pub_date_facet]).to eq('1900')
      expect(doc_hash[:sw_title_display_facet]).to eq("San Francisco, Cal.")
      #doc_hash[:sw_author_sort_facet].should == "\uFFFF San Francisco Cal"
    end
    it 'should merge the hash with the existing hash' do
      doc_hash=@item.to_solr({Solrizer.solr_name('title', :facetable) => "title"})
      expect(doc_hash[Solrizer.solr_name('title', :facetable)]).to eq('title')
      expect(doc_hash[:sw_pub_date_facet]).to eq('1900')
    end
    it 'should not error if there is no descMD' do
      allow(@item.descMetadata).to receive(:ng_xml).and_return(Nokogiri::XML('<xml/>'))
      allow(@item.descMetadata).to receive(:new?).and_return(true)
      expect(@item.to_solr({}).keys.include?(:sw_pub_date_facet)).to eq(false)
    end
    it 'shouldnt error on minimal mods' do
      allow(@item.descMetadata).to receive(:ng_xml).and_return(Nokogiri::XML('
      <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
        <titleInfo>
          <title>San Francisco, Cal.</title>
        </titleInfo>
      </mods>'))
      expect(@item.to_solr({})[:sw_title_full_display_facet]).to eq('San Francisco, Cal.')
      
    end
    it 'should include translated format' do
      doc_hash=@item.to_solr({})
      expect(doc_hash[:sw_format_facet]).to eq(['Image'])
    end
    
  end
end