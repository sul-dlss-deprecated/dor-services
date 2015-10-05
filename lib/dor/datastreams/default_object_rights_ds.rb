module Dor
  class DefaultObjectRightsDS < ActiveFedora::OmDatastream

    set_terminology do |t|
      t.root :path => 'rightsMetadata', :index_as => [:not_searchable]
      t.copyright :path => 'copyright/human', :index_as => [:symbol]
      t.use_statement :path => '/use/human[@type=\'useAndReproduction\']', :index_as => [:symbol]

      t.use do
        t.machine
        t.human
      end

      t.creative_commons :path => '/use/machine', :type => 'creativeCommons'
      t.creative_commons_human :path => '/use/human[@type=\'creativeCommons\']'
      t.open_data_commons :path => '/use/machine', :type => 'openDataCommons'
      t.open_data_commons_human :path => '/use/human[@type=\'openDataCommons\']'
    end

    define_template :creative_commons do |xml|
      xml.use {
        xml.human(:type => 'creativeCommons')
        xml.machine(:type => 'creativeCommons')
      }
    end

    define_template :open_data_commons do |xml|
      xml.use {
        xml.human(:type => 'openDataCommons')
        xml.machine(:type => 'openDataCommons')
      }
    end

    def self.xml_template
      Nokogiri::XML::Builder.new do |xml|
        xml.rightsMetadata {
          xml.access(:type => 'discover') {
            xml.machine {
              xml.world
            }
          }
          xml.access(:type => 'read') {
            xml.machine {
              xml.world
            }
          }
          xml.use {
            xml.human(:type => 'useAndReproduction')
            xml.human(:type => 'creativeCommons')
            xml.machine(:type => 'creativeCommons')
            xml.human(:type => 'openDataCommons')
            xml.machine(:type => 'openDataCommons')
          }
          xml.copyright {
            xml.human
          }
        }
      end.doc
    end
  end
end
