# frozen_string_literal: true

module Dor
  class IdentifiableIndexer
    include SolrDocHelper

    attr_reader :resource
    def initialize(resource:)
      @resource = resource
    end

    ## Module-level variables, shared between ALL mixin includers (and ALL *their* includers/extenders)!
    ## used for caching found values
    @@collection_hash = {}
    @@apo_hash = {}

    # @return [Hash] the partial solr document for identifiable concerns
    def to_solr
      solr_doc = {}
      resource.assert_content_model

      solr_doc[Dor::INDEX_VERSION_FIELD] = Dor::VERSION
      solr_doc['indexed_at_dtsi'] = Time.now.utc.xmlschema
      resource.datastreams.values.each do |ds|
        add_solr_value(solr_doc, 'ds_specs', ds.datastream_spec_string, :string, [:symbol]) unless ds.new?
      end

      add_solr_value(solr_doc, 'title_sort', resource.label, :string, [:stored_sortable])

      rels_doc = Nokogiri::XML(resource.datastreams['RELS-EXT'].content)
      ns_hash = { 'hydra' => 'http://projecthydra.org/ns/relations#', 'fedora' => 'info:fedora/fedora-system:def/relations-external#', 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' }
      apos = rels_doc.search('//rdf:RDF/rdf:Description/hydra:isGovernedBy', ns_hash)
      collections = rels_doc.search('//rdf:RDF/rdf:Description/fedora:isMemberOfCollection', ns_hash)
      solrize_related_obj_titles(solr_doc, apos, @@apo_hash, 'apo_title', 'nonhydrus_apo_title', 'hydrus_apo_title')
      solrize_related_obj_titles(solr_doc, collections, @@collection_hash, 'collection_title', 'nonhydrus_collection_title', 'hydrus_collection_title')
      solr_doc['public_dc_relation_tesim'] ||= solr_doc['collection_title_tesim'] if solr_doc['collection_title_tesim']
      solr_doc['metadata_source_ssi'] = identity_metadata_source
      solr_doc
    end

    # @return [String] calculated value for Solr index
    def identity_metadata_source
      if resource.identityMetadata.otherId('catkey').first ||
         resource.identityMetadata.otherId('barcode').first
        'Symphony'
      else
        'DOR'
      end
    end

    private

    def solrize_related_obj_titles(solr_doc, relationships, title_hash, union_field_name, nonhydrus_field_name, hydrus_field_name)
      # TODO: if you wanted to get a little fancier, you could also solrize a 2 level hierarchy and display using hierarchial facets, like
      # ["SOURCE", "SOURCE : TITLE"] (e.g. ["Hydrus", "Hydrus : Special Collections"], see (exploded) tags in IdentityMetadataDS#to_solr).
      title_type = :symbol # we'll get an _ssim because of the type
      title_attrs = [:stored_searchable] # we'll also get a _tesim from this attr
      relationships.each do |rel_node|
        rel_druid = rel_node['rdf:resource']
        next unless rel_druid # TODO: warning here would also be useful
        rel_druid = rel_druid.gsub('info:fedora/', '')

        # populate cache if necessary
        unless title_hash.key?(rel_druid)
          begin
            related_obj = Dor.find(rel_druid)
            related_obj_title = get_related_obj_display_title(related_obj, rel_druid)
            is_from_hydrus = (related_obj&.tags&.include?('Project : Hydrus'))
            title_hash[rel_druid] = { 'related_obj_title' => related_obj_title, 'is_from_hydrus' => is_from_hydrus }
          rescue ActiveFedora::ObjectNotFoundError
            # This may happen if the given APO or Collection does not exist (bad data)
            title_hash[rel_druid] = { 'related_obj_title' => rel_druid, 'is_from_hydrus' => false }
          end
        end

        # cache should definitely be populated, so just use that to write solr field
        if title_hash[rel_druid]['is_from_hydrus']
          add_solr_value(solr_doc, hydrus_field_name, title_hash[rel_druid]['related_obj_title'], title_type, title_attrs)
        else
          add_solr_value(solr_doc, nonhydrus_field_name, title_hash[rel_druid]['related_obj_title'], title_type, title_attrs)
        end
        add_solr_value(solr_doc, union_field_name, title_hash[rel_druid]['related_obj_title'], title_type, title_attrs)
      end
    end
  end
end
