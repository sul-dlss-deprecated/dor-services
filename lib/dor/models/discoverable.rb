module Dor
  module Discoverable
    extend ActiveSupport::Concern
    #index gryphondor fields
    require 'stanford-mods'
		def to_solr(solr_doc=Hash.new, *args)
			super solr_doc, *args
    
      if self.descMetadata and not self.descMetadata.new?
        stanford_mods_record=Stanford::Mods::Record.new
        stanford_mods_record.from_str(self.descMetadata.ng_xml.to_s)
        doc_hash = { 
          # title fields
          :sw_title_245a_search_facet_facet => stanford_mods_record.sw_short_title,
          :sw_title_245_search_facet_facet => stanford_mods_record.sw_full_title,
          :sw_title_variant_search_facet_facet => stanford_mods_record.sw_addl_titles,
          :sw_title_sort_facet => stanford_mods_record.sw_sort_title,
          :sw_title_245a_display_facet => stanford_mods_record.sw_short_title,
          :sw_title_display_facet => stanford_mods_record.sw_full_title,
          :sw_title_full_display_facet => stanford_mods_record.sw_full_title,
      
          # author fields
          :sw_author_1xx_search_facet_facet => stanford_mods_record.sw_main_author,
          :sw_author_7xx_search_facet_facet => stanford_mods_record.sw_addl_authors,
          :sw_author_person_facet_facet => stanford_mods_record.sw_person_authors,
          :sw_author_other_facet_facet => stanford_mods_record.sw_impersonal_authors,
          :sw_author_sort_facet => stanford_mods_record.sw_sort_author,
          :sw_author_corp_display_facet => stanford_mods_record.sw_corporate_authors,
          :sw_author_meeting_display_facet => stanford_mods_record.sw_meeting_authors,
          :sw_author_person_display_facet => stanford_mods_record.sw_person_authors,
          :sw_author_person_full_display_facet => stanford_mods_record.sw_person_authors,
      
          # subject search fields
           :sw_topic_search_facet_facet => stanford_mods_record.topic_search, 
           :sw_geographic_search_facet_facet => stanford_mods_record.geographic_search,
           :sw_subject_other_search_facet_facet => stanford_mods_record.subject_other_search, 
           :sw_subject_other_subvy_search_facet_facet => stanford_mods_record.subject_other_subvy_search,
           :sw_subject_all_search_facet_facet => stanford_mods_record.subject_all_search, 
           :sw_topic_facet_facet => stanford_mods_record.topic_facet,
           :sw_geographic_facet_facet => stanford_mods_record.geographic_facet,
           :sw_era_facet_facet => stanford_mods_record.era_facet,

          :sw_language => stanford_mods_record.sw_language_facet,
          #:sw_physical =>  stanford_mods_record.term_values([:sw_physical_description, :sw_extent]),
          #:sw_summary_search_facet_facet => stanford_mods_record.term_values(:sw_abstract),
          #:sw_toc_search_facet_facet => stanford_mods_record.term_values(:sw_tableOfContents),
          #:sw_url_suppl => stanford_mods_record.term_values([:sw_related_item, :sw_location, :sw_url]),

          #publish date fields
          :sw_pub_search_facet_facet => stanford_mods_record.place,
          :sw_pub_date_sort_facet => stanford_mods_record.pub_date_sort,
          :sw_pub_date_group_facet_facet => stanford_mods_record.pub_date_groups(stanford_mods_record.pub_date), 
          :sw_pub_date_facet =>stanford_mods_record.pub_date_facet,
          :sw_pub_date_display_facet => stanford_mods_record.pub_date_display,
          :sw_all_search_facet_facet => stanford_mods_record.text
      
        }
        if doc_hash
          solr_doc = doc.merge(doc_hash)
        end
      end
      solr_doc
    end
  end
end