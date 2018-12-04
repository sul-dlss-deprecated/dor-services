# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::PublicDescMetadataService do
  before(:each) { stub_config   }
  after(:each)  { unstub_config }

  let(:obj) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }

  describe '#to_xml' do
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

      let(:obj) do
        mods = read_fixture('ex2_related_mods.xml')
        b = Dor::Item.new
        b.datastreams['descMetadata'].content = mods
        b.datastreams['rightsMetadata'].content = rights_xml
        b
      end

      let(:public_mods) do
        Nokogiri::XML(obj.generate_public_desc_md)
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
        obj.datastreams['rightsMetadata'].content = rxml
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
        expect(public_mods.xpath('//mods:accessCondition[@type="license"]').size).to eq 0
      end

      it 'removes any pre-existing accessConditions already in the mods' do
        expect(obj.descMetadata.ng_xml.xpath('//mods:accessCondition[text()[contains(.,"Public Services")]]').count).to eq 1
        expect(public_mods.xpath('//mods:accessCondition').size).to eq 3
        expect(public_mods.xpath('//mods:accessCondition[text()[contains(.,"Public Services")]]').count).to eq 0
      end

      it 'deals with mods declared as the default xmlns' do
        mods = read_fixture('mods_default_ns.xml')
        b = Dor::Item.new
        b.datastreams['descMetadata'].content = mods
        b.datastreams['rightsMetadata'].content = rights_xml
        expect(b.descMetadata.ng_xml.xpath('//mods:accessCondition[text()[contains(.,"Should not be here anymore")]]', 'mods' => 'http://www.loc.gov/mods/v3').count).to eq(1)

        new_mods = Nokogiri::XML(b.generate_public_desc_md)
        expect(new_mods.xpath('//mods:accessCondition', 'mods' => 'http://www.loc.gov/mods/v3').size).to eq 3
        expect(new_mods.xpath('//mods:accessCondition[text()[contains(.,"Should not be here anymore")]]', 'mods' => 'http://www.loc.gov/mods/v3').count).to eq(0)
      end

      describe 'does not add empty mods nodes when the rightsMetadata has empty' do
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

        let(:blank_obj) do
          mods = read_fixture('ex2_related_mods.xml')
          b = Dor::Item.new
          b.datastreams['descMetadata'].content = mods
          b.datastreams['rightsMetadata'].content = blank_rights_xml
          b
        end

        let(:public_mods) { Nokogiri::XML(blank_obj.generate_public_desc_md) }

        it 'useAndReproduction nodes' do
          expect(public_mods.xpath('//mods:accessCondition[@type="useAndReproduction"]').size).to eq 0
        end

        it 'copyright nodes' do
          expect(public_mods.xpath('//mods:accessCondition[@type="copyright"]').size).to eq 0
        end

        it 'license nodes' do
          expect(public_mods.xpath('//mods:accessCondition[@type="license"]').size).to eq 0
        end
      end
    end
    describe 'add_collection_reference' do
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
        relationships = Nokogiri::XML(relationships_xml)
        allow(obj).to receive(:public_relationships).and_return(relationships)

        allow(Dor).to receive(:find) do |pid|
          pid == 'druid:ab123cd4567' ? obj : collection
        end
      end

      after(:each) do
        Dor::Config.pop!
      end

      describe 'relatedItem' do
        before(:each) do
          obj.datastreams['descMetadata'].ng_xml = Nokogiri::XML(read_fixture('ex2_related_mods.xml'))
          collection.datastreams['descMetadata'].ng_xml = Nokogiri::XML(read_fixture('ex1_mods.xml'))
        end

        let(:public_mods) { Nokogiri::XML(obj.generate_public_desc_md) }

        context 'if the item is a member of a collection' do
          before do
            obj.datastreams['descMetadata'].ng_xml.search('//mods:relatedItem/mods:typeOfResource[@collection=\'yes\']').each do |node|
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
end
