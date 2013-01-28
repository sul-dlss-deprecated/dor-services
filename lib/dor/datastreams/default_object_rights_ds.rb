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
    def self.xml_template
      Nokogiri::XML::Builder.new do |xml|
        xml.rightsMetadata{
          xml.access(:type => 'discovery'){
            xml.machine{
              xml.world
            }
          } 
          xml.access(:type => 'read'){
            xml.machine{
              xml.world
            }
          }
          xml.use{
            xml.human(:type => 'useAndReproduction')
          }
          xml.copyright{
            xml.human
          }
        
      }
    end.doc
  end
end
end