# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::PublicDescMetadataService do
  before { stub_config }
  after { unstub_config }

  subject(:service) { described_class.new(obj) }
  let(:obj) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }

  describe '#ng_xml' do
    subject(:doc) { service.ng_xml }

    context 'with isMemberOfCollection and isConstituentOf relationships' do
      before do
        obj.rels_ext.content = <<-EOXML
          <rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:hydra="http://projecthydra.org/ns/relations#">
            <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
              <hydra:isGovernedBy rdf:resource="info:fedora/druid:789012"></hydra:isGovernedBy>
              <fedora-model:hasModel rdf:resource="info:fedora/hydra:commonMetadata"></fedora-model:hasModel>
              <fedora:isMemberOf rdf:resource="info:fedora/druid:xh235dd9059"></fedora:isMemberOf>
              <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:xh235dd9059"></fedora:isMemberOfCollection>
              <fedora:isConstituentOf rdf:resource="info:fedora/druid:hj097bm8879"></fedora:isConstituentOf>
            </rdf:Description>
          </rdf:RDF>
        EOXML
      end

      before do
        # load up collection and constituent parent items from fixture data
        expect(Dor).to receive(:find).with('druid:xh235dd9059').and_return(instantiate_fixture('druid:xh235dd9059', Dor::Item))
        expect(Dor).to receive(:find).with('druid:hj097bm8879').and_return(instantiate_fixture('druid:hj097bm8879', Dor::Item))
      end

      it 'writes the relationships into MODS' do
        # test that we have 2 expansions
        expect(doc.xpath('//mods:mods/mods:relatedItem[@type="host"]', 'mods' => 'http://www.loc.gov/mods/v3').size).to eq(2)

        # test the validity of the collection expansion
        xpath_expr = '//mods:mods/mods:relatedItem[@type="host" and not(@displayLabel)]/mods:titleInfo/mods:title'
        expect(doc.xpath(xpath_expr, 'mods' => 'http://www.loc.gov/mods/v3').first.text.strip).to eq('David Rumsey Map Collection at Stanford University Libraries')
        xpath_expr = '//mods:mods/mods:relatedItem[@type="host" and not(@displayLabel)]/mods:location/mods:url'
        expect(doc.xpath(xpath_expr, 'mods' => 'http://www.loc.gov/mods/v3').first.text.strip).to match(%r{^https?://purl.*\.stanford\.edu/xh235dd9059$})

        # test the validity of the constituent expansion
        xpath_expr = '//mods:mods/mods:relatedItem[@type="host" and @displayLabel="Appears in"]/mods:titleInfo/mods:title'
        expect(doc.xpath(xpath_expr, 'mods' => 'http://www.loc.gov/mods/v3').first.text.strip).to start_with("Carey's American Atlas: Containing Twenty Maps")
        xpath_expr = '//mods:mods/mods:relatedItem[@type="host" and @displayLabel="Appears in"]/mods:location/mods:url'
        expect(doc.xpath(xpath_expr, 'mods' => 'http://www.loc.gov/mods/v3').first.text.strip).to match(%r{^http://purl.*\.stanford\.edu/hj097bm8879$})
      end
    end
  end

  describe '#to_xml' do
    subject(:xml) { service.to_xml }

    let(:rights_xml) do
      <<-XML
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
    end

    let(:collection) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }

    before do
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

      obj.rightsMetadata.content = rights_xml
      allow(obj).to receive(:public_relationships).and_return(Nokogiri::XML(relationships_xml))

      c_mods = Nokogiri::XML(read_fixture('ex1_mods.xml'))
      collection.descMetadata.content = c_mods.to_s

      allow(Dor).to receive(:find) do |pid|
        pid == 'druid:ab123cd4567' ? obj : collection
      end
    end

    after do
      Dor::Config.pop!
    end

    context 'when using ex2_related_mods.xml' do
      before do
        mods_xml = read_fixture('ex2_related_mods.xml')
        mods = Nokogiri::XML(mods_xml)
        mods.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']').each do |node|
          node.parent.remove
        end
        obj.descMetadata.content = mods.to_s
      end

      it 'adds collections and generates accessConditions' do
        doc = Nokogiri::XML(xml)
        expect(doc.encoding).to eq('UTF-8')
        expect(doc.xpath('//comment()').size).to eq 0
        collections      = doc.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
        collection_title = doc.search('//mods:relatedItem/mods:titleInfo/mods:title')
        collection_uri   = doc.search('//mods:relatedItem/mods:location/mods:url')
        expect(collections.length).to eq 1
        expect(collection_title.length).to eq 1
        expect(collection_uri.length).to eq 1
        expect(collection_title.first.content).to eq 'The complete works of Henry George'
        expect(collection_uri.first.content).to eq 'https://purl.stanford.edu/zb871zd0767'
        %w(useAndReproduction copyright license).each do |term|
          expect(doc.xpath('//mods:accessCondition[@type="' + term + '"]').size).to eq 1
        end
        expect(doc.xpath('//mods:accessCondition[@type="useAndReproduction"]').text).to match(/yada/)
        expect(doc.xpath('//mods:accessCondition[@type="copyright"]').text).to match(/Property rights reside with/)
        expect(doc.xpath('//mods:accessCondition[@type="license"]').text).to match(/This work is licensed under/)
      end
    end

    context 'when using mods_default_ns.xml' do
      before do
        mods_xml = read_fixture('mods_default_ns.xml')
        mods = Nokogiri::XML(mods_xml)
        mods.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']', 'mods' => 'http://www.loc.gov/mods/v3').each do |node|
          node.parent.remove
        end
        obj.descMetadata.content = mods.to_s
      end

      it 'handles mods as the default namespace' do
        doc = Nokogiri::XML(xml)
        collections      = doc.search('//xmlns:relatedItem/xmlns:typeOfResource[@collection=\'yes\']')
        collection_title = doc.search('//xmlns:relatedItem/xmlns:titleInfo/xmlns:title')
        collection_uri   = doc.search('//xmlns:relatedItem/xmlns:location/xmlns:url')
        expect(collections.length).to eq 1
        expect(collection_title.length).to eq 1
        expect(collection_uri.length).to eq 1
        expect(collection_title.first.content).to eq 'The complete works of Henry George'
        expect(collection_uri.first.content).to eq 'https://purl.stanford.edu/zb871zd0767'
        %w(useAndReproduction copyright license).each do |term|
          expect(doc.xpath('//xmlns:accessCondition[@type="' + term + '"]').size).to eq 1
        end
        expect(doc.xpath('//xmlns:accessCondition[@type="useAndReproduction"]').text).to match(/yada/)
        expect(doc.xpath('//xmlns:accessCondition[@type="copyright"]').text).to match(/Property rights reside with/)
        expect(doc.xpath('//xmlns:accessCondition[@type="license"]').text).to match(/This work is licensed under/)
      end
    end
  end

  describe '#add_access_conditions' do
    let(:rights_xml) do
      <<-XML
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
    end

    let(:mods) { read_fixture('ex2_related_mods.xml') }
    let(:obj) do
      b = Dor::Item.new
      b.descMetadata.content = mods
      b.rightsMetadata.content = rights_xml
      b
    end

    let(:public_mods) do
      service.ng_xml
    end

    it 'adds useAndReproduction accessConditions based on rightsMetadata' do
      expect(public_mods.xpath('//mods:accessCondition[@type="useAndReproduction"]').size).to eq 1
      expect(public_mods.xpath('//mods:accessCondition[@type="useAndReproduction"]').text).to match(/yada/)
    end

    it 'adds copyright accessConditions based on rightsMetadata' do
      expect(public_mods.xpath('//mods:accessCondition[@type="copyright"]').size).to eq 1
      expect(public_mods.xpath('//mods:accessCondition[@type="copyright"]').text).to match(/Property rights reside with/)
    end

    it 'adds license accessCondtitions based on creativeCommons or openDataCommons statements' do
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
      obj.rightsMetadata.content = rxml
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
      obj.rightsMetadata.content = rxml
      expect(public_mods.xpath('//mods:accessCondition[@type="license"]').size).to eq 0
    end

    it 'removes any pre-existing accessConditions already in the mods' do
      expect(obj.descMetadata.ng_xml.xpath('//mods:accessCondition[text()[contains(.,"Public Services")]]').count).to eq 1
      expect(public_mods.xpath('//mods:accessCondition').size).to eq 3
      expect(public_mods.xpath('//mods:accessCondition[text()[contains(.,"Public Services")]]').count).to eq 0
    end

    context 'when mods is declared as the default value' do
      let(:mods) { read_fixture('mods_default_ns.xml') }

      it 'deals with mods declared as the default xmlns' do
        expect(obj.descMetadata.ng_xml.xpath('//mods:accessCondition[text()[contains(.,"Should not be here anymore")]]', 'mods' => 'http://www.loc.gov/mods/v3').count).to eq(1)

        expect(public_mods.xpath('//mods:accessCondition', 'mods' => 'http://www.loc.gov/mods/v3').size).to eq 3
        expect(public_mods.xpath('//mods:accessCondition[text()[contains(.,"Should not be here anymore")]]', 'mods' => 'http://www.loc.gov/mods/v3').count).to eq(0)
      end
    end

    context 'when the rightsMetadata has empty nodes' do
      let(:blank_rights_xml) do
        <<-XML
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
      end

      before do
        obj.rightsMetadata.content = blank_rights_xml
      end

      it 'does not add empty mods nodes' do
        expect(public_mods.xpath('//mods:accessCondition[@type="useAndReproduction"]').size).to eq 0
        expect(public_mods.xpath('//mods:accessCondition[@type="copyright"]').size).to eq 0
        expect(public_mods.xpath('//mods:accessCondition[@type="license"]').size).to eq 0
      end
    end
  end

  describe 'add_collection_reference' do
    let(:collection) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }

    before do
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
      allow(obj).to receive(:public_relationships).and_return(relationships)

      allow(Dor).to receive(:find) do |pid|
        pid == 'druid:ab123cd4567' ? obj : collection
      end
    end

    after do
      Dor::Config.pop!
    end

    describe 'relatedItem' do
      let(:mods) { read_fixture('ex2_related_mods.xml') }
      let(:collection_mods) { read_fixture('ex1_mods.xml') }

      before do
        obj.descMetadata.content = mods
        collection.descMetadata.content = collection_mods
      end

      let(:public_mods) { service.ng_xml }

      context 'if the item is a member of a collection' do
        before do
          obj.descMetadata.ng_xml.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']').each do |node|
            node.parent.remove
          end
        end
        it 'adds a relatedItem node for the collection' do
          collections      = public_mods.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
          collection_title = public_mods.search('//mods:relatedItem/mods:titleInfo/mods:title')
          collection_uri   = public_mods.search('//mods:relatedItem/mods:location/mods:url')
          expect(collections.length).to eq 1
          expect(collection_title.length).to eq 1
          expect(collection_uri.length).to eq 1
          expect(collection_title.first.content).to eq 'The complete works of Henry George'
          expect(collection_uri.first.content).to eq 'https://purl.stanford.edu/zb871zd0767'
        end
      end

      it 'replaces an existing relatedItem if there is a parent collection with title' do
        collections      = public_mods.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
        collection_title = public_mods.search('//mods:relatedItem/mods:titleInfo/mods:title')
        collection_uri   = public_mods.search('//mods:relatedItem/mods:location/mods:url')
        expect(collections.length).to eq 1
        expect(collection_title.length).to eq 1
        expect(collection_uri.length).to eq 1
        expect(collection_title.first.content).to eq 'The complete works of Henry George'
        expect(collection_uri.first.content).to eq 'https://purl.stanford.edu/zb871zd0767'
      end

      context 'if there is no collection relationship' do
        let(:relationships) do
          Nokogiri::XML(<<-XML)
          <?xml version="1.0"?>
          <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description rdf:about="info:fedora/druid:jt667tw2770">
              <fedora:isMemberOf rdf:resource="info:fedora/druid:zb871zd0767"/>
              </rdf:Description>
          </rdf:RDF>
          XML
        end

        before do
          allow(obj).to receive(:public_relationships).and_return(relationships)
        end

        it 'does not touch an existing relatedItem if there is no collection relationship' do
          collections      = public_mods.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
          collection_title = public_mods.search('//mods:relatedItem/mods:titleInfo/mods:title')
          expect(collections.length).to eq 1
          expect(collection_title.length).to eq 1
          expect(collection_title.first.content).to eq 'Buckminster Fuller papers, 1920-1983'
        end
      end

      context 'if the referenced collection does not exist' do
        let(:relationships) do
          Nokogiri::XML(<<-XML)
          <?xml version="1.0"?>
          <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description rdf:about="info:fedora/druid:jt667tw2770">
              <fedora:isMemberOf rdf:resource="info:fedora/#{non_existent_druid}"/>
              <fedora:isMemberOfCollection rdf:resource="info:fedora/#{non_existent_druid}"/>
              </rdf:Description>
          </rdf:RDF>
          XML
        end
        let(:non_existent_druid) { 'druid:doesnotexist' }

        before do
          allow(obj).to receive(:public_relationships).and_return(relationships)
          allow(Dor).to receive(:find).with(non_existent_druid).and_raise(ActiveFedora::ObjectNotFoundError)
        end

        it 'does not add relatedItem and does not error out if the referenced collection does not exist' do
          collections      = public_mods.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']')
          collection_title = public_mods.search('//mods:relatedItem/mods:titleInfo/mods:title')
          collection_uri   = public_mods.search('//mods:relatedItem/mods:location/mods:url')
          expect(collections.length).to eq 0
          expect(collection_title.length).to eq 0
          expect(collection_uri.length).to eq 0
        end
      end
    end
  end
end
