# frozen_string_literal: true

module Dor
  # Show the relationships that are publically available
  # removes things like hydra:isGovernedBy and fedora-model:hasModel
  class PublishedRelationshipsFilter
    INCLUDE_ELEMENTS = ['fedora:isMemberOf', 'fedora:isMemberOfCollection', 'fedora:isConstituentOf'].freeze
    NAMESPACE = { 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' }.freeze

    # @param [Dor::Abstract] object
    def initialize(object)
      @obj = object
    end

    def xml
      relationships_ng_xml do |rels_doc|
        statements(rels_doc).each do |rel|
          next if keep?(rel.namespace.prefix, rel.name)

          rel.next_sibling.remove if rel.next_sibling.content.strip.empty?
          rel.remove
        end
      end
    end

    private

    attr_reader :obj

    def statements(rels_doc)
      rels_doc.xpath('/rdf:RDF/rdf:Description/*', NAMESPACE)
    end

    def keep?(prefix, name)
      INCLUDE_ELEMENTS.include?([prefix, name].join(':'))
    end

    # This creates a duplicate of RELS-EXT and yields it to the block
    def relationships_ng_xml
      duplicate_rels_ext.tap do |ng_xml|
        yield(ng_xml)
      end
    end

    def duplicate_rels_ext
      Nokogiri::XML(obj.datastreams['RELS-EXT'].content)
    end
  end
end
