require 'nokogiri'
require 'date'
require 'time'

module Dor
  class ProvenanceMetadataService

    def self.add_provenance(dor_item, workflow_id, event_text)
      druid = dor_item.pid
      # workflow_xml = get_workflow_xml(druid, workflow_id)
      workflow_provenance = create_workflow_provenance(druid, workflow_id, event_text)
      dsname = 'provenanceMetadata'
      if dor_item.datastream_names.include?(dsname)
        ds = dor_item.datastreams[dsname]
        old_provenance = ds.content
        ds.ng_xml = update_provenance(old_provenance, workflow_provenance)
      else
        ds = dor_item.datastreams[dsname]
        ds.ng_xml = workflow_provenance
      end
      ds.save
    end

    # not used
    def self.get_workflow_xml(druid, workflow_id)
      Dor::WorkflowService.get_workflow_xml('dor', druid, workflow_id)
    end

    # @return [String]
    def self.create_workflow_provenance(druid, workflow_id, event_text)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.provenanceMetadata(:objectId => druid) {
          xml.agent(:name => 'DOR') {
            xml.what(:object => druid) {
              xml.event(:who => "DOR-#{workflow_id}", :when => Time.new.iso8601) {
                xml.text(event_text)
              }
            }
          }
        }
      end
      builder.doc
    end

  # Reformat the XML
  # @param[String]
  def self.parse_xml_remove_blank_nodes(old_provenance)
    # http://blog.slashpoundbang.com/post/1454850669/how-to-pretty-print-xml-with-nokogiri
    Nokogiri::XML(old_provenance) { |x| x.noblanks }
  end

      # Append new stanzas in the contentMetadata for the googleMETS and technicalMetadata files
  # @param[String, Hash<Symbol,String>]
  def self.update_provenance(old_provenance, workflow_provenance)
    pm_xml = Nokogiri::XML(old_provenance)
    builder = Nokogiri::XML::Builder.with(pm_xml.at 'provenanceMetadata') do |xml|
      xml << workflow_provenance.xpath('/provenanceMetadata/agent').first.to_xml
    end
    parse_xml_remove_blank_nodes(builder.to_xml)
  end

  end

end