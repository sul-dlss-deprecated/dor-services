module Dor
  class DescribableIndexer
    attr_reader :resource
    def initialize(resource:)
      @resource = resource
    end

    # @return [Hash] the partial solr document for describable concerns
    def to_solr
      add_metadata_format_to_solr_doc.merge(add_mods_to_solr_doc)
    end

    def add_metadata_format_to_solr_doc
      { 'metadata_format_ssim' => 'mods' }
    end

    def add_mods_to_solr_doc
      solr_doc = {}
      mods_sources = {
        sw_title_display: %w(sw_display_title_tesim),
        main_author_w_date: %w(sw_author_ssim sw_author_tesim),
        sw_sort_author: %w(sw_author_sort_ssi),
        sw_language_facet: %w(sw_language_ssim sw_language_tesim),
        sw_genre: %w(sw_genre_ssim sw_genre_tesim),
        format_main: %w(sw_format_ssim sw_format_tesim),
        topic_facet: %w(sw_topic_ssim sw_topic_tesim),
        era_facet: %w(sw_subject_temporal_ssim sw_subject_temporal_tesim),
        geographic_facet: %w(sw_subject_geographic_ssim sw_subject_geographic_tesim),
        [:term_values, :typeOfResource] => %w(mods_typeOfResource_ssim mods_typeOfResource_tesim),
        pub_year_sort_str: %w(sw_pub_date_sort_ssi),
        pub_year_int: %w(sw_pub_date_sort_isi),
        pub_year_display_str: %w(sw_pub_date_facet_ssi)
      }

      mods_sources.each_pair do |meth, solr_keys|
        vals = meth.is_a?(Array) ? resource.stanford_mods.send(meth.shift, *meth) : resource.stanford_mods.send(meth)

        next if vals.nil? || (vals.respond_to?(:empty?) && vals.empty?)

        solr_keys.each do |key|
          solr_doc[key] ||= []
          solr_doc[key].push(*vals)
        end
        # asterisk to avoid multi-dimensional array: push values, not the array
      end

      # convert multivalued fields to single value
      %w(sw_pub_date_sort_ssi sw_pub_date_sort_isi sw_pub_date_facet_ssi).each do |key|
        solr_doc[key] = solr_doc[key].first unless solr_doc[key].nil?
      end
      # some fields get explicit "(none)" placeholder values, mostly for faceting
      %w(sw_language_tesim sw_genre_tesim sw_format_tesim).each do |key|
        solr_doc[key] = ['(none)'] if solr_doc[key].nil? || solr_doc[key].empty?
      end
      solr_doc
    end
  end
end
