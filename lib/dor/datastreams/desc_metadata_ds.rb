module Dor
class DescMetadataDS < ActiveFedora::OmDatastream 
  include SolrDocHelper
  
  MODS_NS = 'http://www.loc.gov/mods/v3'
  set_terminology do |t|
    t.root :path => 'mods', :xmlns => MODS_NS, :index_as => [:not_searchable]
    t.originInfo :index_as => [:not_searchable] do
      t.publisher :index_as => [:searchable, :stored_searchable]
      t.place :index_as => [:not_searchable] do
        t.placeTerm :attributes => {:type => 'text'}, :index_as => [:searchable, :stored_searchable]
      end
    end
    t.title_info(:path=>"titleInfo") {
           t.main_title(:index_as=>[:facetable],:path=>"title", :label=>"title") {
             t.main_title_lang(:path=>{:attribute=> "xml:lang"})
           }
         }
    t.coordinates :index_as => [:searchable]
    t.extent :index_as => [:searchable]
    t.scale :index_as => [:searchable]
    t.topic :index_as => [:searchable]
    t.abstract :index_as=>[:displayable]
  end
  
  def self.xml_template
    Nokogiri::XML::Builder.new do |xml|
      xml.mods( 'xmlns' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',:version => '3.3', "xsi:schemaLocation" => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd'){
     		xml.titleInfo{
     			xml.title 
     			}
   			}
    end.doc
  end
 
 

end
end
