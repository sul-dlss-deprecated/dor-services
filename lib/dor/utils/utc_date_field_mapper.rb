class UtcDateFieldMapper < Solrizer::FieldMapper::Default
  [:searchable,:facetable,:displayable,:sortable,:unstemmed_searchable].each do |index_type|
    index_as index_type do |type|
      type.date { |value| Time.parse(value).utc.xmlschema }
    end
  end
end
