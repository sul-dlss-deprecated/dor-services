module Dor
  class DefaultObjectRightsDS < ActiveFedora::NokogiriDatastream 

    set_terminology do |t|
      t.root :path => 'rightsMetadata', :index_as => [:not_searchable]
      t.copyright :path => 'copyright/human'
      t.use_statement :path => '/use/human', :argument => 'useAndReproduction'
      t.use
      t.creative_commons :path => '/use/machine', :argument => 'creativeCommons'
    end
    
    define_template :creative_commons do |xml|
       xml.use {
         xml.human(:type => "creativeCommons")
         xml.machine(:type => "creativeCommons")
       }
     end
  end
end