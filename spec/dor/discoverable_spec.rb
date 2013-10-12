require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'Dor::Discoverable' do
  before(:each) { stub_config   }
  after(:each)  { unstub_config }
  before :each do
    @item=instantiate_fixture("cj765pw7168", Dor::Item)
    @item.descMetadata.stub(:new?).and_return(false)
    @item.stub(:milestones).and_return({})
    @item.descMetadata.stub(:ng_xml).and_return(Nokogiri::XML('
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
      doc_hash[:sw_pub_date_facet].should == '1900'
      doc_hash[:sw_title_display_facet].should == "San Francisco, Cal."
      #doc_hash[:sw_author_sort_facet].should == "\uFFFF San Francisco Cal"
    end
    it 'should merge the hash with the existing hash' do
      doc_hash=@item.to_solr({Solrizer.solr_name('title', :facetable) => "title"})
      doc_hash[Solrizer.solr_name('title', :facetable)].should == 'title'
      doc_hash[:sw_pub_date_facet].should == '1900'
    end
    it 'should not error if there is no descMD' do
      @item.descMetadata.stub(:ng_xml).and_return(Nokogiri::XML('<xml/>'))
      @item.descMetadata.stub(:new?).and_return(true)
      @item.to_solr({}).keys.include?(:sw_pub_date_facet).should == false
    end
    it 'shouldnt error on minimal mods' do
      @item.descMetadata.stub(:ng_xml).and_return(Nokogiri::XML('
      <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
        <titleInfo>
          <title>San Francisco, Cal.</title>
        </titleInfo>
      </mods>'))
      @item.to_solr({})[:sw_title_full_display_facet].should == 'San Francisco, Cal.'
      
    end
    it 'should include translated format' do
      doc_hash=@item.to_solr({})
      doc_hash[:sw_format_facet].should == ['Image']
    end
    
  end
end