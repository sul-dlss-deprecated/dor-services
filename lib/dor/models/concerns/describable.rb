# frozen_string_literal: true

module Dor
  module Describable
    extend ActiveSupport::Concern

    MODS_TO_DC_XSLT = Nokogiri::XSLT(File.new(File.expand_path(File.dirname(__FILE__) + '/mods2dc.xslt')))
    XMLNS_OAI_DC = 'http://www.openarchives.org/OAI/2.0/oai_dc/'
    XMLNS_DC = 'http://purl.org/dc/elements/1.1/'

    class CrosswalkError < RuntimeError; end

    included do
      has_metadata name: 'descMetadata', type: Dor::DescMetadataDS, label: 'Descriptive Metadata', control_group: 'M'
    end

    require 'stanford-mods'

    # intended for read-access, "as SearchWorks would see it", mostly for to_solr()
    # @param [Nokogiri::XML::Document] content Nokogiri descMetadata document (overriding internal data)
    # @param [boolean] ns_aware namespace awareness toggle for from_nk_node()
    def stanford_mods(content = nil, ns_aware = true)
      @stanford_mods ||= begin
        m = Stanford::Mods::Record.new
        desc = content.nil? ? descMetadata.ng_xml : content
        m.from_nk_node(desc.root, ns_aware)
        m
      end
    end

    def fetch_descMetadata_datastream
      candidates = datastreams['identityMetadata'].otherId.collect(&:to_s)
      metadata_id = Dor::MetadataService.resolvable(candidates).first
      metadata_id.nil? ? nil : Dor::MetadataService.fetch(metadata_id.to_s)
    end

    def build_descMetadata_datastream(ds)
      content = fetch_descMetadata_datastream
      return nil if content.nil?

      ds.dsLabel = 'Descriptive Metadata'
      ds.ng_xml = Nokogiri::XML(content)
      ds.ng_xml.normalize_text!
      ds.content = ds.ng_xml.to_xml
    end

    # Generates Dublin Core from the MODS in the descMetadata datastream using the LoC mods2dc stylesheet
    #    Should not be used for the Fedora DC datastream
    # @raise [CrosswalkError] Raises an Exception if the generated DC is empty or has no children
    # @return [Nokogiri::Doc] the DublinCore XML document object
    def generate_dublin_core(include_collection_as_related_item: true)
      desc_md = if include_collection_as_related_item
                  Nokogiri::XML(generate_public_desc_md(include_access_conditions: false))
                else
                  descMetadata.ng_xml
                end

      dc_doc = MODS_TO_DC_XSLT.transform(desc_md)
      dc_doc.xpath('/oai_dc:dc/*[count(text()) = 0]', oai_dc: XMLNS_OAI_DC).remove # Remove empty nodes
      raise CrosswalkError, "Dor::Item#generate_dublin_core produced incorrect xml (no root):\n#{dc_doc.to_xml}" if dc_doc.root.nil?
      raise CrosswalkError, "Dor::Item#generate_dublin_core produced incorrect xml (no children):\n#{dc_doc.to_xml}" if dc_doc.root.children.size == 0

      dc_doc
    end

    # @return [String] Public descriptive medatada XML
    def generate_public_desc_md(**options)
      PublicDescMetadataService.new(self).to_xml(**options)
    end

    # @param [Boolean] force Overwrite existing XML
    # @return [String] descMetadata.content XML
    def set_desc_metadata_using_label(force = false)
      raise 'Cannot proceed, there is already content in the descriptive metadata datastream: ' + descMetadata.content.to_s unless force || descMetadata.new?

      label = self.label
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.mods(Dor::DescMetadataDS::MODS_HEADER_CONFIG) do
          xml.titleInfo do
            xml.title label
          end
        end
      end
      descMetadata.content = builder.to_xml
    end

    def self.get_collection_title(obj)
      obj.full_title
    end

    def full_title
      stanford_mods.sw_title_display
    end
  end
end
