module SolrDocHelper
  def add_solr_value(solr_doc, field_name, value, field_type = :default, index_types = [:searchable])
    if Solrizer::VERSION > '3'
      case field_type
        when :symbol
          index_types << field_type
      end
      ::Solrizer.insert_field(solr_doc, field_name, value, *index_types)
    else
      index_types.each { |index_type|
        ::Solrizer::Extractor.insert_solr_field_value(solr_doc, ::ActiveFedora::SolrService.solr_name(field_name, field_type, index_type), value)
      }
    end
  end
end
