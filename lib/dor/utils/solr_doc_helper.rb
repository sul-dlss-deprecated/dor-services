module SolrDocHelper

  def add_solr_value(solr_doc, field_name, value, field_type = :default, index_types = [:searchable])
    index_types.each { |index_type|
      ::Solrizer::Extractor.insert_solr_field_value(solr_doc, ::ActiveFedora::SolrService.solr_name(field_name, field_type, index_type), value)
    }
  end

end
