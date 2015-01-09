require 'spec_helper'

describe SimpleDublinCoreDs do
  subject { SimpleDublinCoreDs.from_xml @xml }

  describe "#to_solr" do
    it "should do OM mapping" do
      @xml = '<oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>title</dc:title>
        <dc:creator>creator</dc:creator>
        <dc:identifier>identifier</dc:identifier>
      </oai_dc:dc>'

      expect(subject.to_solr[Solrizer.solr_name('title', :searchable)]).to include('title')
      expect(subject.to_solr[Solrizer.solr_name('creator', :searchable)]).to include('creator')
      expect(subject.to_solr[Solrizer.solr_name('identifier', :searchable)]).to include('identifier')
    end

    context "sort fields" do
    it "should only produce single valued fields" do
      @xml = '<oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:title>title</dc:title>
        <dc:title>title2</dc:title>
        <dc:creator>creator</dc:creator>
        <dc:creator>creator2</dc:creator>
        <dc:identifier>identifier</dc:identifier>
      </oai_dc:dc>'

      expect(subject.to_solr[Solrizer.solr_name('dc_title', :sortable)]).to be_a_kind_of(String)
      expect(subject.to_solr[Solrizer.solr_name('dc_creator', :sortable)]).to be_a_kind_of(String)
    end

    it "should create sort fields for each type of identifier" do
      @xml = '<oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:identifier>druid:identifier</dc:identifier>
        <dc:identifier>druid:identifier2</dc:identifier>
        <dc:identifier>uuid:identifier2</dc:identifier>
        <dc:identifier>uuid:identifierxyz</dc:identifier>
      </oai_dc:dc>'

      expect(subject.to_solr[Solrizer.solr_name('dc_identifier_druid', :sortable)]).to be_a_kind_of(String)
      expect(subject.to_solr[Solrizer.solr_name('dc_identifier_uuid', :sortable)]).to be_a_kind_of(String)
    end
    end
  end
end
