# frozen_string_literal: true

module Dor
  module Describable
    extend ActiveSupport::Concern

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

    def full_title
      stanford_mods.sw_title_display
    end
  end
end
