# frozen_string_literal: true

module Dor
  module Publishable
    extend ActiveSupport::Concern
    # strips away the relationships that should not be shown in public desc metadata
    # @return [Nokogiri::XML]
    def public_relationships
      include_elements = ['fedora:isMemberOf', 'fedora:isMemberOfCollection', 'fedora:isConstituentOf']
      rels_doc = Nokogiri::XML(datastreams['RELS-EXT'].content)
      rels_doc.xpath('/rdf:RDF/rdf:Description/*', 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#').each do |rel|
        unless include_elements.include?([rel.namespace.prefix, rel.name].join(':'))
          rel.next_sibling.remove if rel.next_sibling.content.strip.empty?
          rel.remove
        end
      end
      rels_doc
    end
  end
end
