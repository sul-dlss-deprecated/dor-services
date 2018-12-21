# frozen_string_literal: true

module Dor
  class DublinCoreService
    MODS_TO_DC_XSLT = Nokogiri::XSLT(File.new(File.expand_path(File.dirname(__FILE__) + '/mods2dc.xslt')))
    XMLNS_OAI_DC = 'http://www.openarchives.org/OAI/2.0/oai_dc/'
    class CrosswalkError < RuntimeError; end

    def initialize(work, include_collection_as_related_item: true)
      @work = work
      @include_collection = include_collection_as_related_item
    end

    # Generates Dublin Core from the MODS in the descMetadata datastream using the LoC mods2dc stylesheet
    #    Should not be used for the Fedora DC datastream
    # @raise [CrosswalkError] Raises an Exception if the generated DC is empty or has no children
    # @return [Nokogiri::Doc] the DublinCore XML document object
    def to_xml
      dc_doc = MODS_TO_DC_XSLT.transform(desc_md)
      dc_doc.xpath('/oai_dc:dc/*[count(text()) = 0]', oai_dc: XMLNS_OAI_DC).remove # Remove empty nodes
      raise CrosswalkError, "Dor::Item#generate_dublin_core produced incorrect xml (no root):\n#{dc_doc.to_xml}" if dc_doc.root.nil?
      raise CrosswalkError, "Dor::Item#generate_dublin_core produced incorrect xml (no children):\n#{dc_doc.to_xml}" if dc_doc.root.children.size == 0

      dc_doc
    end

    private

    def desc_md
      return PublicDescMetadataService.new(work).ng_xml(include_access_conditions: false) if include_collection?

      work.descMetadata.ng_xml
    end

    def include_collection?
      @include_collection
    end
    attr_reader :work
  end
end
