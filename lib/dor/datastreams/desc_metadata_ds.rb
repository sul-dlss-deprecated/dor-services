module Dor
class DescMetadataDS < ActiveFedora::NokogiriDatastream 
  include SolrDocHelper
  
  MODS_NS = 'http://www.loc.gov/mods/v3'
  set_terminology do |t|
    t.root :path => 'mods', :xmlns => MODS_NS, :index_as => [:not_searchable]
    t.originInfo :index_as => [:not_searchable] do
      t.publisher :index_as => [:searchable, :displayable]
      t.place :index_as => [:not_searchable] do
        t.placeTerm :attributes => {:type => 'text'}, :index_as => [:searchable, :displayable]
      end
    end
    t.coordinates :index_as => [:searchable]
    t.extent :index_as => [:searchable]
    t.scale :index_as => [:searchable]
    t.topic :index_as => [:searchable]
  end

  def to_solr(solr_doc=Hash.new, *args)
    self.solrize_profile(solr_doc) if self.respond_to?(:solrize_profile)
    solr_doc
  end
end
end