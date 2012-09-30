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

      subject.to_solr['dc_title_t'].should include('title')
      subject.to_solr['dc_creator_t'].should include('creator')
      subject.to_solr['dc_identifier_t'].should include('identifier')
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

      subject.to_solr['dc_title_sort'].should have(1).item
      subject.to_solr['dc_creator_sort'].should have(1).item
    end

    it "should create sort fields for each type of identifier" do
      @xml = '<oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:identifier>druid:identifier</dc:identifier>
        <dc:identifier>druid:identifier2</dc:identifier>
        <dc:identifier>uuid:identifier2</dc:identifier>
        <dc:identifier>uuid:identifierxyz</dc:identifier>
      </oai_dc:dc>'

      subject.to_solr['dc_identifier_druid_sort'].should have(1).item
      subject.to_solr['dc_identifier_uuid_sort'].should have(1).item
    end
    end
  end
end
