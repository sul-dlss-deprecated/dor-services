# frozen_string_literal: true

module Dor
  module Preservable
    extend ActiveSupport::Concern

    included do
      has_metadata name: 'provenanceMetadata', type: ProvenanceMetadataDS, label: 'Provenance Metadata'
    end

    def build_provenanceMetadata_datastream(workflow_id, event_text)
      workflow_provenance = create_workflow_provenance(workflow_id, event_text)
      ds = datastreams['provenanceMetadata']
      ds.label ||= 'Provenance Metadata'
      ds.ng_xml = workflow_provenance
      ds.save
    end

    def sdr_ingest_transfer(agreement_id)
      SdrIngestService.transfer(self, agreement_id)
    end

    private

    # @return [Nokogiri::Document]
    def create_workflow_provenance(workflow_id, event_text)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.provenanceMetadata(objectId: pid) do
          xml.agent(name: 'DOR') do
            xml.what(object: pid) do
              xml.event(who: "DOR-#{workflow_id}", when: Time.new.iso8601) do
                xml.text(event_text)
              end
            end
          end
        end
      end
      builder.doc
    end
  end
end
