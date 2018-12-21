# frozen_string_literal: true

module Dor
  module Describable
    extend ActiveSupport::Concern
    extend Deprecation
    self.deprecation_horizon = 'dor-services version 7.0.0'

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
    # @return [Nokogiri::XML::Document] the DublinCore XML document object
    def generate_dublin_core(include_collection_as_related_item: true)
      DublinCoreService.new(self, include_collection_as_related_item: include_collection_as_related_item).ng_xml
    end
    deprecation_deprecate generate_dublin_core: 'Use DublinCoreService#ng_xml instead'

    # @return [String] Public descriptive medatada XML
    def generate_public_desc_md(**options)
      PublicDescMetadataService.new(self).to_xml(**options)
    end
    deprecation_deprecate generate_public_desc_md: 'Use PublicDescMetadataService#to_xml instead'

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
