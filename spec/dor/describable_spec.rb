require 'spec_helper'

class DescribableItem < ActiveFedora::Base
  include Dor::Identifiable
  include Dor::Describable
  include Dor::Processable
end
class SimpleItem < ActiveFedora::Base
  include Dor::Describable
end

describe Dor::Describable do
  before(:each) { stub_config	 }
  after(:each)	 { unstub_config }

  before :each do
    @item = instantiate_fixture('druid:ab123cd4567', DescribableItem)
    @obj = instantiate_fixture('druid:ab123cd4567', DescribableItem)
    @obj.datastreams['descMetadata'].content = read_fixture('ex1_mods.xml')
    @simple = instantiate_fixture('druid:ab123cd4567', SimpleItem)
  end

  it 'should add a creator_title field' do
    doc = {}
    expected_dc = read_fixture('ex1_dc.xml')
    @found = 0
    @simple.stub(:generate_dublin_core).and_return(Nokogiri::XML(expected_dc))
    #this is hacky but effective
    @simple.stub(:add_solr_value) do |doc,val, field, otherstuff|
      if val == 'creator_title'
        field.should == 'George, Henry, 1839-1897The complete works of Henry George'
        @found = 1
      end
    end
    @simple.to_solr(doc)
    @found.should == 1
    end

  it "should have a descMetadata datastream" do
    @item.datastreams['descMetadata'].should be_a(Dor::DescMetadataDS)
  end

  it "should know its metadata format" do
    @item.stub(:find_metadata_file).and_return(nil)
    FakeWeb.register_uri(:get, "#{Dor::Config.metadata.catalog.url}/?barcode=36105049267078", :body => read_fixture('ab123cd4567_descMetadata.xml'))
    @item.build_datastream('descMetadata')
    @item.metadata_format.should == 'mods'
  end

  it "should provide a descMetadata datastream builder" do
    @item.stub(:find_metadata_file).and_return(nil)
    Dor::MetadataService.class_eval { class << self; alias_method :_fetch, :fetch; end }
    Dor::MetadataService.should_receive(:fetch).with('barcode:36105049267078').and_return { Dor::MetadataService._fetch('barcode:36105049267078') }
    @item.datastreams['descMetadata'].ng_xml.to_s.should be_equivalent_to('<?xml version="1.0"?>
          <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
            <titleInfo>
              <title/>
            </titleInfo>
          </mods>')
    @item.build_datastream('descMetadata')
    @item.datastreams['descMetadata'].ng_xml.to_s.should_not be_equivalent_to('<?xml version="1.0"?>
          <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
            <titleInfo>
              <title/>
            </titleInfo>
          </mods>')
  end

  it "produces dublin core from the MODS in the descMetadata datastream" do
    mods = read_fixture('ex1_mods.xml')
    expected_dc = read_fixture('ex1_dc.xml')

    b = Dor::Item.new
    b.datastreams['descMetadata'].content = mods
    dc = b.generate_dublin_core
    dc.should be_equivalent_to(expected_dc)
  end

  it "produces dublin core Stanford-specific mapping for repository, collection and location, from the MODS in the descMetadata datastream" do
    mods = read_fixture('ex2_related_mods.xml')
    expected_dc = read_fixture('ex2_related_dc.xml')

    b = Dor::Item.new
    b.datastreams['descMetadata'].content = mods
    dc = b.generate_dublin_core
    EquivalentXml.equivalent?(dc, expected_dc).should be
  end

  it "throws an exception if the generated dc has no root element" do
    b = DescribableItem.new
    b.datastreams['descMetadata'].content = '<tei><stuff>ha</stuff></tei>'
    lambda {b.generate_dublin_core}.should raise_error(Dor::Describable::CrosswalkError)
  end

  describe "#add_access_conditions" do

    let(:rights_xml) { <<-XML
      <rightsMetadata>
        <copyright>
          <human type="copyright">
            Property rights reside with the repository. Copyright &#xA9; Stanford University. All Rights Reserved.
          </human>
        </copyright>
        <access type="discover">
          <machine>
            <world/>
          </machine>
        </access>
        <access type="read">
          <machine>
            <world/>
          </machine>
        </access>
        <use>
          <human type="useAndReproduction">
            Image from the Glen McLaughlin Map Collection yada ...
          </human>
          <machine type="creativeCommons">by-nc</machine>
          <human type="creativeCommons">
            This work is licensed under a Creative Commons Attribution-NonCommercial 3.0 Unported License
          </human>
        </use>
      </rightsMetadata>
      XML
    }

    let(:obj) {
      mods = read_fixture('ex2_related_mods.xml')
      b = Dor::Item.new
      b.datastreams['descMetadata'].content = mods
      b.datastreams['rightsMetadata'].content = rights_xml
      b
    }

    let(:public_mods) {
      obj.datastreams['descMetadata'].ng_xml.dup(1)
    }

    it "adds useAndReproduction accessConditions based on rightsMetadata" do
      obj.add_access_conditions(public_mods)
      expect(public_mods.xpath('//mods:accessCondition[@type="useAndReproduction"]').size).to eq(1)
      expect(public_mods.xpath('//mods:accessCondition[@type="useAndReproduction"]').text).to match(/yada/)
    end

    it "adds copyright accessConditions based on rightsMetadata" do
      obj.add_access_conditions(public_mods)
      expect(public_mods.xpath('//mods:accessCondition[@type="copyright"]').size).to eq(1)
      expect(public_mods.xpath('//mods:accessCondition[@type="copyright"]').text).to match(/Property rights reside with/)
    end

    it "adds license accessCondtitions based on creativeCommons or openDataCommons statements" do
      obj.add_access_conditions(public_mods)
      expect(public_mods.xpath('//mods:accessCondition[@type="license"]').size).to eq(1)
      expect(public_mods.xpath('//mods:accessCondition[@type="license"]').text).to match(/by-nc: This work is licensed under/)
    end

    it "searches for creativeCommons and openData /use/machine/@type case-insensitively" do
      rxml = <<-XML
        <rightsMetadata>
          <use>
            <machine type="openDataCommoNS">by-nc</machine>
            <human type="OpenDATAcommOns">
              Open Data hoo ha
            </human>
          </use>
        </rightsMetadata>
        XML
      obj.datastreams['rightsMetadata'].content = rxml
      obj.add_access_conditions(public_mods)
      expect(public_mods.xpath('//mods:accessCondition[@type="license"]').size).to eq(1)
      expect(public_mods.xpath('//mods:accessCondition[@type="license"]').text).to match(/by-nc: Open Data hoo ha/)
    end

    it "does not add license accessConditions when createCommons or openData has a value of none in rightsMetadata" do
      rxml = <<-XML
        <rightsMetadata>
          <use>
            <machine type="OpenDatA">none</machine>
          </use>
        </rightsMetadata>
        XML
      obj.datastreams['rightsMetadata'].content = rxml
      obj.add_access_conditions(public_mods)
      expect(public_mods.xpath('//mods:accessCondition[@type="license"]').size).to eq(0)
    end

    it "removes any pre-existing accessConditions already in the mods" do
      expect(obj.descMetadata.ng_xml.xpath('//mods:accessCondition[text()[contains(.,"Public Services")]]').count).to eq(1)
      obj.add_access_conditions(public_mods)
      expect(public_mods.xpath('//mods:accessCondition').size).to eq(3)
      expect(public_mods.xpath('//mods:accessCondition[text()[contains(.,"Public Services")]]').count).to eq(0)
    end

    it "deals with mods declared as the default xmlns" do
      mods = read_fixture('mods_default_ns.xml')
      b = Dor::Item.new
      b.datastreams['descMetadata'].content = mods
      b.datastreams['rightsMetadata'].content = rights_xml
      expect(b.descMetadata.ng_xml.xpath('//mods:accessCondition[text()[contains(.,"Should not be here anymore")]]', 'mods' => 'http://www.loc.gov/mods/v3').count).to eq(1)

      new_mods = b.datastreams['descMetadata'].ng_xml.dup(1)
      b.add_access_conditions(new_mods)
      expect(new_mods.xpath('//mods:accessCondition', 'mods' => 'http://www.loc.gov/mods/v3').size).to eq(3)
      expect(new_mods.xpath('//mods:accessCondition[text()[contains(.,"Should not be here anymore")]]', 'mods' => 'http://www.loc.gov/mods/v3').count).to eq(0)
    end

    describe "does not add empty mods nodes when the rightsMetadata has empty" do

      let(:blank_rights_xml) { <<-XML
        <rightsMetadata>
          <copyright>
            <human type="copyright"></human>
          </copyright>
          <access type="discover">
            <machine>
              <world/>
            </machine>
          </access>
          <access type="read">
            <machine>
              <world/>
            </machine>
          </access>
          <use>
            <human type="useAndReproduction" />
            <machine type="creativeCommons">by-nc</machine>
            <human type="creativeCommons"></human>
          </use>
        </rightsMetadata>
        XML
      }

      let(:blank_obj) {
        mods = read_fixture('ex2_related_mods.xml')
        b = Dor::Item.new
        b.datastreams['descMetadata'].content = mods
        b.datastreams['rightsMetadata'].content = blank_rights_xml
        b
      }

      it "useAndReproduction nodes" do
        blank_obj.add_access_conditions(public_mods)
        expect(public_mods.xpath('//mods:accessCondition[@type="useAndReproduction"]').size).to eq(0)
      end

      it "copyright nodes" do
        blank_obj.add_access_conditions(public_mods)
        expect(public_mods.xpath('//mods:accessCondition[@type="copyright"]').size).to eq(0)
      end

      it "license nodes" do
        blank_obj.add_access_conditions(public_mods)
        expect(public_mods.xpath('//mods:accessCondition[@type="license"]').size).to eq(0)
      end
    end

  end

  describe 'add_collection_reference' do

    before(:each) do
      Dor::Config.push! { stacks.document_cache_host 'purl.stanford.edu' }

      relationships_xml=<<-XML
      <?xml version="1.0"?>
      <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description rdf:about="info:fedora/druid:jt667tw2770">
      <fedora:isMemberOf rdf:resource="info:fedora/druid:zb871zd0767"/>
      <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:zb871zd0767"/>
      </rdf:Description>
      </rdf:RDF>
      XML
      relationships=Nokogiri::XML(relationships_xml)
      @item.stub(:public_relationships).and_return(relationships)

      @collection = instantiate_fixture('druid:ab123cd4567', Dor::Item)
      Dor::Item.stub(:find) do |pid|
        if pid == 'druid:ab123cd4567'
          @item
        else
          @collection
        end
      end

    end

    after(:each) do
      Dor::Config.pop!
    end

    it "adds a relatedItem node for the collection if the item is a member of a collection" do
      mods_xml = read_fixture('ex2_related_mods.xml')
      mods=Nokogiri::XML(mods_xml)
      mods.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']').each do |node|
        node.parent.remove()
      end
      c_mods=Nokogiri::XML(read_fixture('ex1_mods.xml'))
      @collection.datastreams['descMetadata'].content = c_mods.to_s

      @item.add_collection_reference(mods)

      xml = mods
      EquivalentXml.equivalent?(xml.to_s,@item.descMetadata.ng_xml.to_s).should == false
      collections=xml.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
      collections.length.should == 1
      collection_title=xml.search('//mods:relatedItem/mods:titleInfo/mods:title')
      collection_title.length.should ==1
      collection_title.first.content.should == 'complete works of Henry George'
      collection_uri = xml.search('//mods:relatedItem/mods:identifier[@type="uri"]')
      expect(collection_uri.length).to eq(1)
      expect(collection_uri.first.content).to eq "http://purl.stanford.edu/zb871zd0767"
    end

    it "replaces an existing relatedItem if there is a parent collection with title" do
      mods_xml = read_fixture('ex2_related_mods.xml')
      mods=Nokogiri::XML(mods_xml)
      c_mods=Nokogiri::XML(read_fixture('ex1_mods.xml'))
      @collection.datastreams['descMetadata'].content = c_mods.to_s

      @item.add_collection_reference(mods)

      xml = mods
      EquivalentXml.equivalent?(xml.to_s,@item.descMetadata.ng_xml.to_s).should == false
      collections=xml.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
      collections.length.should == 1
      collection_title=xml.search('//mods:relatedItem/mods:titleInfo/mods:title')
      collection_title.length.should ==1
      collection_title.first.content.should == 'complete works of Henry George'
      collection_uri = xml.search('//mods:relatedItem/mods:identifier[@type="uri"]')
      expect(collection_uri.length).to eq(1)
      expect(collection_uri.first.content).to eq "http://purl.stanford.edu/zb871zd0767"
    end

    it "does not touch an existing relatedItem if there is no collection relationship" do
      b = instantiate_fixture('druid:ab123cd4567', Dor::Item)
      relationships_xml=<<-XML
      <?xml version="1.0"?>
      <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about="info:fedora/druid:jt667tw2770">
          <fedora:isMemberOf rdf:resource="info:fedora/druid:zb871zd0767"/>
          </rdf:Description>
      </rdf:RDF>
      XML
      relationships=Nokogiri::XML(relationships_xml)
      @item.stub(:public_relationships).and_return(relationships)

      mods_xml = read_fixture('ex2_related_mods.xml')
      mods=Nokogiri::XML(mods_xml)
      @collection.datastreams['descMetadata'].content = mods.to_s

      @item.add_collection_reference(mods)

      xml = mods
      EquivalentXml.equivalent?(xml.to_s,@item.descMetadata.ng_xml.to_s).should == false
      collections=xml.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
      collections.length.should == 1
      collection_title=xml.search('//mods:relatedItem/mods:titleInfo/mods:title')
      collection_title.length.should ==1
      collection_title.first.content.should == 'Buckminster Fuller papers, 1920-1983'
    end
  end

  describe "#generate_public_desc_md" do

    let(:rights_xml) { <<-XML
      <rightsMetadata>
        <copyright>
          <human type="copyright">
            Property rights reside with the repository. Copyright &#xA9; Stanford University. All Rights Reserved.
          </human>
        </copyright>
        <access type="discover">
          <machine>
            <world/>
          </machine>
        </access>
        <access type="read">
          <machine>
            <world/>
          </machine>
        </access>
        <use>
          <human type="useAndReproduction">
            Image from the Glen McLaughlin Map Collection yada ...
          </human>
          <machine type="creativeCommons">by-nc</machine>
          <human type="creativeCommons">
            This work is licensed under a Creative Commons Attribution-NonCommercial 3.0 Unported License
          </human>
        </use>
      </rightsMetadata>
      XML
    }

    let(:itm) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }
    let(:collection) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }

    before(:each) do
      Dor::Config.push! { stacks.document_cache_host 'purl.stanford.edu' }

      relationships_xml=<<-XML
      <?xml version="1.0"?>
      <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description rdf:about="info:fedora/druid:jt667tw2770">
      <fedora:isMemberOf rdf:resource="info:fedora/druid:zb871zd0767"/>
      <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:zb871zd0767"/>
      </rdf:Description>
      </rdf:RDF>
      XML
      relationships=Nokogiri::XML(relationships_xml)

      itm.datastreams['rightsMetadata'].content = rights_xml
      itm.stub(:public_relationships).and_return(relationships)

      c_mods=Nokogiri::XML(read_fixture('ex1_mods.xml'))
      collection.datastreams['descMetadata'].content = c_mods.to_s

      Dor::Item.stub(:find) do |pid|
        if pid == 'druid:ab123cd4567'
          itm
        else
          collection
        end
      end
    end

    after(:each) do
      Dor::Config.pop!
    end

    it "adds collections and generates accessConditions" do
      mods_xml = read_fixture('ex2_related_mods.xml')
      mods=Nokogiri::XML(mods_xml)
      mods.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']').each do |node|
        node.parent.remove
      end
      itm.datastreams['descMetadata'].content = mods.to_s

      xml = itm.generate_public_desc_md
      doc = Nokogiri::XML(xml)
      expect(doc.encoding).to eq('UTF-8')
      expect(doc.xpath('//comment()').size).to eq 0
      collections      = doc.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
      collection_title = doc.search('//mods:relatedItem/mods:titleInfo/mods:title')
      collection_uri   = doc.search('//mods:relatedItem/mods:identifier[@type="uri"]')
      expect(collections.length     ).to eq 1
      expect(collection_title.length).to eq 1
      expect(collection_uri.length  ).to eq 1
      expect(collection_title.first.content).to eq 'complete works of Henry George'
      expect(collection_uri.first.content  ).to eq 'http://purl.stanford.edu/zb871zd0767'
      %w(useAndReproduction copyright license).each { |term|
        expect(doc.xpath('//mods:accessCondition[@type="' + term + '"]').size).to eq 1
      }
      expect(doc.xpath('//mods:accessCondition[@type="useAndReproduction"]').text).to match(/yada/)
      expect(doc.xpath('//mods:accessCondition[@type="copyright"]').size).to eq(1)
      expect(doc.xpath('//mods:accessCondition[@type="copyright"]').text).to match(/Property rights reside with/)
      expect(doc.xpath('//mods:accessCondition[@type="license"]').size).to eq(1)
      expect(doc.xpath('//mods:accessCondition[@type="license"]').text).to match(/This work is licensed under/)
    end

    it "handles mods as the default namespace" do
      mods_xml = read_fixture('mods_default_ns.xml')
      mods=Nokogiri::XML(mods_xml)
      mods.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']', 'mods' => 'http://www.loc.gov/mods/v3').each do |node|
        node.parent.remove
      end
      itm.datastreams['descMetadata'].content = mods.to_s

      xml = itm.generate_public_desc_md
      doc = Nokogiri::XML(xml)
      collections=doc.search('//xmlns:relatedItem/xmlns:typeOfResource[@collection=\'yes\']')
      collections.length.should == 1
      collection_title=doc.search('//xmlns:relatedItem/xmlns:titleInfo/xmlns:title')
      collection_title.length.should ==1
      collection_title.first.content.should == 'complete works of Henry George'
      collection_uri = doc.search('//xmlns:relatedItem/xmlns:identifier[@type="uri"]')
      expect(collection_uri.length).to eq(1)
      expect(collection_uri.first.content).to eq "http://purl.stanford.edu/zb871zd0767"
      expect(doc.xpath('//xmlns:accessCondition[@type="useAndReproduction"]').size).to eq(1)
      expect(doc.xpath('//xmlns:accessCondition[@type="useAndReproduction"]').text).to match(/yada/)
      expect(doc.xpath('//xmlns:accessCondition[@type="copyright"]').size).to eq(1)
      expect(doc.xpath('//xmlns:accessCondition[@type="copyright"]').text).to match(/Property rights reside with/)
      expect(doc.xpath('//xmlns:accessCondition[@type="license"]').size).to eq(1)
      expect(doc.xpath('//xmlns:accessCondition[@type="license"]').text).to match(/This work is licensed under/)
    end
  end


describe 'get_collection_title' do
  it 'should get a titleInfo/title' do
    @item = instantiate_fixture('druid:ab123cd4567', Dor::Item)
    @item.descMetadata.content=<<-XML
    <?xml version="1.0"?>
    <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
    <titleInfo>
    <title>Foxml Test Object</title>
    </titleInfo>
    </mods>
    XML

    Dor::Describable.get_collection_title(@item).should == 'Foxml Test Object'
  end

  it 'should include a subtitle if there is one' do
    @item = instantiate_fixture('druid:ab123cd4567', Dor::Item)
    @item.descMetadata.content=<<-XML
    <?xml version="1.0"?>
    <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
    <titleInfo>
    <title>Foxml Test Object</title>
    <subTitle>Hello world</note>
    </titleInfo>
    </mods>
    XML
    Dor::Describable.get_collection_title(@item).should == 'Foxml Test Object (Hello world)'
  end
end


it "throws an exception if the generated dc has only a root element with no children" do
  mods = <<-EOXML
  <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  version="3.3"
  xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd" />
  EOXML

  b = Dor::Item.new
  b.stub(:add_collection_reference).and_return(mods)
  b.datastreams['descMetadata'].content = mods

  lambda {b.generate_dublin_core}.should raise_error(Dor::Describable::CrosswalkError)
end
describe 'update_title' do
  it 'should update the title' do
    found=false

    @obj.update_title('new title')
    @obj.descMetadata.ng_xml.search('//mods:mods/mods:titleInfo/mods:title', 'mods' => 'http://www.loc.gov/mods/v3').each do |node|
      node.content.should == 'new title'
      found=true
    end
    found.should == true
  end
  it 'should raise an exception if the mods lacks a title' do
    @obj.update_title('new title')
    @obj.descMetadata.ng_xml.search('//mods:mods/mods:titleInfo/mods:title', 'mods' => 'http://www.loc.gov/mods/v3').each do |node|
      node.remove
    end
    lambda {@obj.update_title('druid:oo201oo0001', 'new title')}.should raise_error
  end
end
describe 'add_identifier' do
  it 'should add an identifier' do
    @obj.add_identifier('type', 'new attribute')
    res=@obj.descMetadata.ng_xml.search('//mods:identifier[@type="type"]','mods' => 'http://www.loc.gov/mods/v3')
    res.length.should > 0
    res.each do |node|
      node.content.should == 'new attribute'
    end
  end
end
describe 'delete_identifier' do
  it 'should delete an identifier' do
    @obj.add_identifier('type', 'new attribute')
    res=@obj.descMetadata.ng_xml.search('//mods:identifier[@type="type"]','mods' => 'http://www.loc.gov/mods/v3')
    res.length.should > 0
    res.each do |node|
      node.content.should == 'new attribute'
    end
    @obj.delete_identifier('type', 'new attribute').should == true
    res=@obj.descMetadata.ng_xml.search('//mods:identifier[@type="type"]','mods' => 'http://www.loc.gov/mods/v3')
    res.length.should == 0
  end
  it 'should return false if there was nothing to delete' do
    @obj.delete_identifier( 'type', 'new attribute').should == false
  end
end
describe 'set_desc_metadata_using_label' do
  it 'should create basic mods using the object label' do
    @obj.datastreams['descMetadata'].stub(:content).and_return ''
    @obj.set_desc_metadata_using_label()
    @obj.datastreams['descMetadata'].ng_xml.should be_equivalent_to <<-XML
    <?xml version="1.0"?>
    <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
    <titleInfo>
    <title>Foxml Test Object</title>
    </titleInfo>
    </mods>
    XML

  end
  it 'should throw an exception if there is content in the descriptive metadata stream' do
    #@obj.stub(:descMetadata).and_return(ActiveFedora::OmDatastream.new)
    @obj.descMetadata.stub(:new?).and_return(false)
    lambda{@obj.set_desc_metadata_using_label()}.should raise_error
  end
  it 'should run if there is content in the descriptive metadata stream and force is true' do
    @obj.set_desc_metadata_using_label(false)
    @obj.datastreams['descMetadata'].ng_xml.should be_equivalent_to <<-XML
    <?xml version="1.0"?>
    <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
    <titleInfo>
    <title>Foxml Test Object</title>
    </titleInfo>
    </mods>
    XML
  end
end
end
