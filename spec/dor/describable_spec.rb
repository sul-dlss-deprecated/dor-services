require 'spec_helper'

class DescribableItem < ActiveFedora::Base
  include Dor::Identifiable
  include Dor::Describable
  include Dor::Processable
end
class SimpleItem < ActiveFedora::Base
  include Dor::Describable
end

RSpec::Matchers.define_negated_matcher :a_hash_excluding, :a_hash_including

describe Dor::Describable do
  before(:each) { stub_config   }
  after(:each)  { unstub_config }

  before :each do
    @simple = instantiate_fixture('druid:ab123cd4567', SimpleItem)
    @item   = instantiate_fixture('druid:ab123cd4567', DescribableItem)
    @obj    = instantiate_fixture('druid:ab123cd4567', DescribableItem)
    @obj.datastreams['descMetadata'].content = read_fixture('ex1_mods.xml')
  end

  it 'should add a creator_title field' do
    expected_dc = read_fixture('ex1_dc.xml')
    found = 0
    allow(@simple).to receive(:generate_dublin_core).and_return(Nokogiri::XML(expected_dc))
    # this is hacky but effective
    allow(@simple).to receive(:add_solr_value) do |doc, field, value, otherstuff|
      if field == 'creator_title'
        expect(value).to eq('George, Henry, 1839-1897The complete works of Henry George')
        found = 1
      end
    end
    @simple.to_solr({})
    expect(found).to eq 1
  end

  it 'should have a descMetadata datastream' do
    expect(@item.datastreams['descMetadata']).to be_a(Dor::DescMetadataDS)
  end

  it 'should provide a descMetadata datastream builder' do
    stub_request(:get, "#{Dor::Config.metadata.catalog.url}/?barcode=36105049267078").to_return(:body => read_fixture('ab123cd4567_descMetadata.xml'))
    allow(@item).to receive(:find_metadata_file).and_return(nil)
    expect(Dor::MetadataService).to receive(:fetch).with('barcode:36105049267078').and_call_original
    xml = <<-END_OF_XML
    <?xml version="1.0"?>
    <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
      <titleInfo>
        <title/>
      </titleInfo>
    </mods>
    END_OF_XML
    expect(@item.datastreams['descMetadata'].ng_xml.to_s).to be_equivalent_to(xml)
    @item.build_datastream('descMetadata')
    expect(@item.datastreams['descMetadata'].ng_xml.to_s).not_to be_equivalent_to(xml)
  end

  it 'produces dublin core from the MODS in the descMetadata datastream' do
    b = Dor::Item.new
    b.datastreams['descMetadata'].content = read_fixture('ex1_mods.xml')
    expect(b.generate_dublin_core).to be_equivalent_to read_fixture('ex1_dc.xml')
  end

  it 'produces dublin core Stanford-specific mapping for repository, collection and location, from the MODS in the descMetadata datastream' do
    b = Dor::Item.new
    b.datastreams['descMetadata'].content = read_fixture('ex2_related_mods.xml')
    expect(b.generate_dublin_core).to be_equivalent_to read_fixture('ex2_related_dc.xml')
  end

  describe '#add_access_conditions' do

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

    it 'adds useAndReproduction accessConditions based on rightsMetadata' do
      obj.add_access_conditions(public_mods)
      expect(public_mods.xpath('//mods:accessCondition[@type="useAndReproduction"]').size).to eq 1
      expect(public_mods.xpath('//mods:accessCondition[@type="useAndReproduction"]').text).to match(/yada/)
    end

    it 'adds copyright accessConditions based on rightsMetadata' do
      obj.add_access_conditions(public_mods)
      expect(public_mods.xpath('//mods:accessCondition[@type="copyright"]').size).to eq 1
      expect(public_mods.xpath('//mods:accessCondition[@type="copyright"]').text).to match(/Property rights reside with/)
    end

    it 'adds license accessCondtitions based on creativeCommons or openDataCommons statements' do
      obj.add_access_conditions(public_mods)
      expect(public_mods.xpath('//mods:accessCondition[@type="license"]').size).to eq 1
      expect(public_mods.xpath('//mods:accessCondition[@type="license"]').text).to match(/by-nc: This work is licensed under/)
    end

    it 'searches for creativeCommons and openData /use/machine/@type case-insensitively' do
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

    it 'does not add license accessConditions when createCommons or openData has a value of none in rightsMetadata' do
      rxml = <<-XML
        <rightsMetadata>
          <use>
            <machine type="OpenDatA">none</machine>
          </use>
        </rightsMetadata>
        XML
      obj.datastreams['rightsMetadata'].content = rxml
      obj.add_access_conditions(public_mods)
      expect(public_mods.xpath('//mods:accessCondition[@type="license"]').size).to eq 0
    end

    it 'removes any pre-existing accessConditions already in the mods' do
      expect(obj.descMetadata.ng_xml.xpath('//mods:accessCondition[text()[contains(.,"Public Services")]]').count).to eq 1
      obj.add_access_conditions(public_mods)
      expect(public_mods.xpath('//mods:accessCondition').size).to eq 3
      expect(public_mods.xpath('//mods:accessCondition[text()[contains(.,"Public Services")]]').count).to eq 0
    end

    it 'deals with mods declared as the default xmlns' do
      mods = read_fixture('mods_default_ns.xml')
      b = Dor::Item.new
      b.datastreams['descMetadata'].content = mods
      b.datastreams['rightsMetadata'].content = rights_xml
      expect(b.descMetadata.ng_xml.xpath('//mods:accessCondition[text()[contains(.,"Should not be here anymore")]]', 'mods' => 'http://www.loc.gov/mods/v3').count).to eq(1)

      new_mods = b.datastreams['descMetadata'].ng_xml.dup(1)
      b.add_access_conditions(new_mods)
      expect(new_mods.xpath('//mods:accessCondition', 'mods' => 'http://www.loc.gov/mods/v3').size).to eq 3
      expect(new_mods.xpath('//mods:accessCondition[text()[contains(.,"Should not be here anymore")]]', 'mods' => 'http://www.loc.gov/mods/v3').count).to eq(0)
    end

    describe 'does not add empty mods nodes when the rightsMetadata has empty' do

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

      it 'useAndReproduction nodes' do
        blank_obj.add_access_conditions(public_mods)
        expect(public_mods.xpath('//mods:accessCondition[@type="useAndReproduction"]').size).to eq 0
      end

      it 'copyright nodes' do
        blank_obj.add_access_conditions(public_mods)
        expect(public_mods.xpath('//mods:accessCondition[@type="copyright"]').size).to eq 0
      end

      it 'license nodes' do
        blank_obj.add_access_conditions(public_mods)
        expect(public_mods.xpath('//mods:accessCondition[@type="license"]').size).to eq 0
      end
    end

  end

  describe 'add_collection_reference' do

    before(:each) do
      Dor::Config.push! { stacks.document_cache_host 'purl.stanford.edu' }

      relationships_xml = <<-XML
      <?xml version="1.0"?>
      <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description rdf:about="info:fedora/druid:jt667tw2770">
      <fedora:isMemberOf rdf:resource="info:fedora/druid:zb871zd0767"/>
      <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:zb871zd0767"/>
      </rdf:Description>
      </rdf:RDF>
      XML
      relationships = Nokogiri::XML(relationships_xml)
      allow(@item).to receive(:public_relationships).and_return(relationships)

      @collection = instantiate_fixture('druid:ab123cd4567', Dor::Item)
      allow(Dor).to receive(:find) do |pid|
        pid == 'druid:ab123cd4567' ? @item : @collection
      end
    end

    after(:each) do
      Dor::Config.pop!
    end

    describe 'relatedItem' do
      before(:each) do
        @xml = Nokogiri::XML(read_fixture('ex2_related_mods.xml'))
        @collection.datastreams['descMetadata'].content = Nokogiri::XML(read_fixture('ex1_mods.xml')).to_s
      end

      it 'adds a relatedItem node for the collection if the item is a member of a collection' do
        @xml.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']').each do |node|
          node.parent.remove
        end
        @item.add_collection_reference(@xml)
        expect(@item.descMetadata.ng_xml).not_to be_equivalent_to(@xml)
        collections      = @xml.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
        collection_title = @xml.search('//mods:relatedItem/mods:titleInfo/mods:title')
        collection_uri   = @xml.search('//mods:relatedItem/mods:location/mods:url')
        expect(collections.length     ).to eq 1
        expect(collection_title.length).to eq 1
        expect(collection_uri.length  ).to eq 1
        expect(collection_title.first.content).to eq 'complete works of Henry George'
        expect(collection_uri.first.content  ).to eq 'https://purl.stanford.edu/zb871zd0767'
      end

      it 'replaces an existing relatedItem if there is a parent collection with title' do
        @item.add_collection_reference(@xml)
        expect(@item.descMetadata.ng_xml).not_to be_equivalent_to(@xml)
        collections      = @xml.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
        collection_title = @xml.search('//mods:relatedItem/mods:titleInfo/mods:title')
        collection_uri   = @xml.search('//mods:relatedItem/mods:location/mods:url')
        expect(collections.length     ).to eq 1
        expect(collection_title.length).to eq 1
        expect(collection_uri.length  ).to eq 1
        expect(collection_title.first.content).to eq 'complete works of Henry George'
        expect(collection_uri.first.content  ).to eq 'https://purl.stanford.edu/zb871zd0767'
      end

      it 'does not touch an existing relatedItem if there is no collection relationship' do
        relationships_xml = <<-XML
        <?xml version="1.0"?>
        <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about="info:fedora/druid:jt667tw2770">
            <fedora:isMemberOf rdf:resource="info:fedora/druid:zb871zd0767"/>
            </rdf:Description>
        </rdf:RDF>
        XML
        relationships = Nokogiri::XML(relationships_xml)
        allow(@item).to receive(:public_relationships).and_return(relationships)
        @item.add_collection_reference(@xml)
        expect(@item.descMetadata.ng_xml).not_to be_equivalent_to(@xml)
        collections      = @xml.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
        collection_title = @xml.search('//mods:relatedItem/mods:titleInfo/mods:title')
        expect(collections.length     ).to eq 1
        expect(collection_title.length).to eq 1
        expect(collection_title.first.content).to eq 'Buckminster Fuller papers, 1920-1983'
      end

      it 'does not add relatedItem and does not error out if the referenced collection does not exist' do
        non_existent_druid = 'druid:doesnotexist'
        expect(Dor).to receive(:find).with(non_existent_druid).and_raise(ActiveFedora::ObjectNotFoundError)
        relationships_xml = <<-XML
        <?xml version="1.0"?>
        <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about="info:fedora/druid:jt667tw2770">
            <fedora:isMemberOf rdf:resource="info:fedora/#{non_existent_druid}"/>
            <fedora:isMemberOfCollection rdf:resource="info:fedora/#{non_existent_druid}"/>
            </rdf:Description>
        </rdf:RDF>
        XML
        relationships = Nokogiri::XML(relationships_xml)
        expect(@item).to receive(:public_relationships).and_return(relationships)
        @item.add_collection_reference(@xml)
        expect(@item.descMetadata.ng_xml).not_to be_equivalent_to(@xml)
        collections      = @xml.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
        collection_title = @xml.search('//mods:relatedItem/mods:titleInfo/mods:title')
        collection_uri   = @xml.search('//mods:relatedItem/mods:location/mods:url')
        expect(collections.length     ).to eq 0
        expect(collection_title.length).to eq 0
        expect(collection_uri.length  ).to eq 0
      end
    end
  end

  describe '#generate_public_desc_md' do

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

      relationships_xml = <<-XML
      <?xml version="1.0"?>
      <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description rdf:about="info:fedora/druid:jt667tw2770">
      <fedora:isMemberOf rdf:resource="info:fedora/druid:zb871zd0767"/>
      <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:zb871zd0767"/>
      </rdf:Description>
      </rdf:RDF>
      XML

      itm.datastreams['rightsMetadata'].content = rights_xml
      allow(itm).to receive(:public_relationships).and_return(Nokogiri::XML(relationships_xml))

      c_mods = Nokogiri::XML(read_fixture('ex1_mods.xml'))
      collection.datastreams['descMetadata'].content = c_mods.to_s

      allow(Dor).to receive(:find) do |pid|
        pid == 'druid:ab123cd4567' ? itm : collection
      end
    end

    after(:each) do
      Dor::Config.pop!
    end

    it 'adds collections and generates accessConditions' do
      mods_xml = read_fixture('ex2_related_mods.xml')
      mods = Nokogiri::XML(mods_xml)
      mods.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']').each do |node|
        node.parent.remove
      end
      itm.datastreams['descMetadata'].content = mods.to_s

      doc = Nokogiri::XML(itm.generate_public_desc_md)
      expect(doc.encoding).to eq('UTF-8')
      expect(doc.xpath('//comment()').size).to eq 0
      collections      = doc.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
      collection_title = doc.search('//mods:relatedItem/mods:titleInfo/mods:title')
      collection_uri   = doc.search('//mods:relatedItem/mods:location/mods:url')
      expect(collections.length     ).to eq 1
      expect(collection_title.length).to eq 1
      expect(collection_uri.length  ).to eq 1
      expect(collection_title.first.content).to eq 'complete works of Henry George'
      expect(collection_uri.first.content  ).to eq 'https://purl.stanford.edu/zb871zd0767'
      %w(useAndReproduction copyright license).each{ |term|
        expect(doc.xpath('//mods:accessCondition[@type="' + term + '"]').size).to eq 1
      }
      expect(doc.xpath('//mods:accessCondition[@type="useAndReproduction"]').text).to match(/yada/)
      expect(doc.xpath('//mods:accessCondition[@type="copyright"]'         ).text).to match(/Property rights reside with/)
      expect(doc.xpath('//mods:accessCondition[@type="license"]'           ).text).to match(/This work is licensed under/)
    end

    it 'handles mods as the default namespace' do
      mods_xml = read_fixture('mods_default_ns.xml')
      mods = Nokogiri::XML(mods_xml)
      mods.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']', 'mods' => 'http://www.loc.gov/mods/v3').each do |node|
        node.parent.remove
      end
      itm.datastreams['descMetadata'].content = mods.to_s

      doc = Nokogiri::XML(itm.generate_public_desc_md)
      collections      = doc.search('//xmlns:relatedItem/xmlns:typeOfResource[@collection=\'yes\']')
      collection_title = doc.search('//xmlns:relatedItem/xmlns:titleInfo/xmlns:title')
      collection_uri   = doc.search('//xmlns:relatedItem/xmlns:location/xmlns:url')
      expect(collections.length     ).to eq 1
      expect(collection_title.length).to eq 1
      expect(collection_uri.length  ).to eq 1
      expect(collection_title.first.content).to eq 'complete works of Henry George'
      expect(collection_uri.first.content  ).to eq 'https://purl.stanford.edu/zb871zd0767'
      %w(useAndReproduction copyright license).each{ |term|
        expect(doc.xpath('//xmlns:accessCondition[@type="' + term + '"]').size).to eq 1
      }
      expect(doc.xpath('//xmlns:accessCondition[@type="useAndReproduction"]').text).to match(/yada/)
      expect(doc.xpath('//xmlns:accessCondition[@type="copyright"]'         ).text).to match(/Property rights reside with/)
      expect(doc.xpath('//xmlns:accessCondition[@type="license"]'           ).text).to match(/This work is licensed under/)
    end
  end

  describe 'get_collection_title' do
    before(:each) do
      @item = instantiate_fixture('druid:ab123cd4567', Dor::Item)
    end
    it 'should get a titleInfo/title' do
      @item.descMetadata.content = <<-XML
      <?xml version="1.0"?>
      <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
      <titleInfo>
      <title>Foxml Test Object</title>
      </titleInfo>
      </mods>
      XML
      expect(Dor::Describable.get_collection_title(@item)).to eq 'Foxml Test Object'
    end

    it 'should include a subtitle if there is one' do
      @item.descMetadata.content = <<-XML
      <?xml version="1.0"?>
      <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
      <titleInfo>
      <title>Foxml Test Object</title>
      <subTitle>Hello world</note>
      </titleInfo>
      </mods>
      XML
      expect(Dor::Describable.get_collection_title(@item)).to eq 'Foxml Test Object (Hello world)'
    end
  end

  it 'throws an exception if the generated dc has only a root element with no children' do
    mods = <<-EOXML
    <mods:mods xmlns:mods="http://www.loc.gov/mods/v3"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    version="3.3"
    xsi:schemaLocation="http://www.loc.gov/mods/v3 http://cosimo.stanford.edu/standards/mods/v3/mods-3-3.xsd" />
    EOXML

    b = Dor::Item.new
    allow(b).to receive(:add_collection_reference).and_return(mods)
    b.datastreams['descMetadata'].content = mods
    expect {b.generate_dublin_core}.to raise_error(Dor::Describable::CrosswalkError)
  end

  describe 'set_desc_metadata_using_label' do
    it 'should create basic mods using the object label' do
      allow(@obj.datastreams['descMetadata']).to receive(:content).and_return ''
      @obj.set_desc_metadata_using_label
      expect(@obj.datastreams['descMetadata'].ng_xml).to be_equivalent_to <<-XML
      <?xml version="1.0"?>
      <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
      <titleInfo>
      <title>Foxml Test Object</title>
      </titleInfo>
      </mods>
      XML
    end
    it 'should throw an exception if there is content in the descriptive metadata stream' do
      # @obj.stub(:descMetadata).and_return(ActiveFedora::OmDatastream.new)
      allow(@obj.descMetadata).to receive(:new?).and_return(false)
      expect{@obj.set_desc_metadata_using_label}.to raise_error(StandardError)
    end
    it 'should run if there is content in the descriptive metadata stream and force is true' do
      @obj.set_desc_metadata_using_label(false)
      expect(@obj.datastreams['descMetadata'].ng_xml).to be_equivalent_to <<-XML
      <?xml version="1.0"?>
      <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="3.3" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd">
      <titleInfo>
      <title>Foxml Test Object</title>
      </titleInfo>
      </mods>
      XML
    end
  end

  describe 'stanford_mods accessor to DS' do
    it 'should fetch Stanford::Mods object' do
      expect(@obj.methods).to include(:stanford_mods)
      sm = nil
      expect{sm = @obj.stanford_mods}.not_to raise_error
      expect(sm).to be_kind_of(Stanford::Mods::Record)
      expect(sm.format_main).to eq(['Book'])
      expect(sm.pub_year_sort_str).to eq('1911')
    end
    it 'should allow override argument(s)' do
      sm = nil
      nk = Nokogiri::XML('<mods><genre>ape</genre></mods>')
      expect{sm = @obj.stanford_mods(nk, false)}.not_to raise_error
      expect(sm).to be_kind_of(Stanford::Mods::Record)
      expect(sm.genre.text).to eq('ape')
      expect(sm.pub_year_sort_str).to be_nil
    end
  end

  describe 'to_solr' do
    before :each do
      allow(@obj).to receive(:milestones).and_return({})
      @doc = @obj.to_solr
      expect(@doc).not_to be_nil
    end
    it 'should include values from stanford_mods' do
      # require 'pp'; pp doc
      expect(@doc).to match a_hash_including(
        'sw_language_ssim'            => ['English'],
        'sw_language_tesim'           => ['English'],
        'sw_format_ssim'              => ['Book'],
        'sw_format_tesim'             => ['Book'],
        'sw_subject_temporal_ssim'    => ['1800-1900'],
        'sw_subject_temporal_tesim'   => ['1800-1900'],
        'sw_pub_date_sort_ssi'        => '1911',
        'sw_pub_date_sort_isi'        => 1911,
        'sw_pub_date_facet_ssi'       => '1911'
      )
    end
    it 'should not include empty values' do
      @doc.keys.sort_by{|k| k.to_s}.each { |k|
        expect(@doc).to include(k)
        expect(@doc).to match a_hash_excluding({k => nil})
        expect(@doc).to match a_hash_excluding({k => []})
      }
    end
  end

  describe 'to_solr: more mods stuff' do
    before :each do
      allow(@obj).to receive(:milestones).and_return({})
      @obj.datastreams['descMetadata'].content = read_fixture('bs646cd8717_mods.xml')
      @doc = @obj.to_solr
      expect(@doc).not_to be_nil
    end
    it 'searchworks date-fu: temporal periods and pub_dates' do
      expect(@doc).to match a_hash_including(
        'sw_subject_temporal_ssim'  => a_collection_containing_exactly('18th century', '17th century'),
        'sw_subject_temporal_tesim' => a_collection_containing_exactly('18th century', '17th century'),
        'sw_pub_date_sort_ssi'      => '1600',
        'sw_pub_date_sort_isi'      => 1600,
        'sw_pub_date_facet_ssi'     => '1600'
      )
    end
    it 'subject geographic fields' do
      expect(@doc).to match a_hash_including(
        'sw_subject_geographic_ssim'  => %w(Europe Europe),
        'sw_subject_geographic_tesim' => %w(Europe Europe)
      )
    end
    it 'genre fields' do
      genre_list = ['Thesis/Dissertation']
      expect(@doc).to match a_hash_including(
        'sw_genre_ssim'               => genre_list,
        'sw_genre_tesim'              => genre_list
      )
    end
  end

end
