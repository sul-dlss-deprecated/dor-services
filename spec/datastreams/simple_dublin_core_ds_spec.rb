# frozen_string_literal: true

require 'spec_helper'

describe 'Dor::SimpleDublinCoreDs' do
  describe '#to_solr' do
    it 'should do OM mapping' do
      @xml = '<oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>title</dc:title>
        <dc:creator>creator</dc:creator>
        <dc:identifier>identifier</dc:identifier>
      </oai_dc:dc>'

      title_field   = Solrizer.solr_name('title', :stored_searchable)
      creator_field = Solrizer.solr_name('creator', :stored_searchable)
      id_field      = Solrizer.solr_name('identifier', :stored_searchable)
      dublin = Dor::SimpleDublinCoreDs.from_xml(@xml)
      expect(dublin.to_solr).to match a_hash_including(title_field, creator_field, id_field)
      expect(dublin.to_solr[title_field]).to eq ['title']
      expect(dublin.to_solr[creator_field]).to eq ['creator']
      expect(dublin.to_solr[id_field]).to eq ['identifier']
    end

    context 'sort fields' do
      it 'should only produce single valued fields' do
        @xml = '<oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title>title</dc:title>
          <dc:title>title2</dc:title>
          <dc:creator>creator</dc:creator>
          <dc:creator>creator2</dc:creator>
          <dc:identifier>identifier</dc:identifier>
        </oai_dc:dc>'

        dublin = Dor::SimpleDublinCoreDs.from_xml(@xml)
        expect(dublin.to_solr[Solrizer.solr_name('dc_title', :stored_sortable)]).to be_a_kind_of(String)
        expect(dublin.to_solr[Solrizer.solr_name('dc_title', :stored_sortable)]).to eq 'title'
        expect(dublin.to_solr[Solrizer.solr_name('dc_creator', :stored_sortable)]).to be_a_kind_of(String)
        expect(dublin.to_solr[Solrizer.solr_name('dc_creator', :stored_sortable)]).to eq 'creator'
      end

      it 'should create sort fields for each type of identifier' do
        @xml = '<oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:identifier>druid:identifier</dc:identifier>
          <dc:identifier>druid:identifier2</dc:identifier>
          <dc:identifier>uuid:identifier2</dc:identifier>
          <dc:identifier>uuid:identifierxyz</dc:identifier>
        </oai_dc:dc>'

        dublin = Dor::SimpleDublinCoreDs.from_xml(@xml)
        expect(dublin.to_solr[Solrizer.solr_name('dc_identifier_druid', :stored_sortable)]).to be_a_kind_of(String)
        expect(dublin.to_solr[Solrizer.solr_name('dc_identifier_druid', :stored_sortable)]).to eq 'identifier'
        expect(dublin.to_solr[Solrizer.solr_name('dc_identifier_uuid', :stored_sortable)]).to be_a_kind_of(String)
        expect(dublin.to_solr[Solrizer.solr_name('dc_identifier_uuid', :stored_sortable)]).to eq 'identifier2'
      end
    end
  end
end
