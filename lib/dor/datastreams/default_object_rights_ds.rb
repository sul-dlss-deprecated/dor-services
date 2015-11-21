module Dor
  class DefaultObjectRightsDS < ActiveFedora::OmDatastream

    set_terminology do |t|
      t.root :path => 'rightsMetadata', :index_as => [:not_searchable]
      t.copyright :path => 'copyright/human', :index_as => [:symbol]
      t.use_statement :path => '/use/human[@type=\'useAndReproduction\']', :index_as => [:symbol]

      # t.use do
      #   t.machine
      #   t.human
      # end

      t.creative_commons :path => '/use/machine[@type=\'creativeCommons\']', :type => 'creativeCommons' do
        t.uri :path => '@uri'
      end
      t.creative_commons_human :path => '/use/human[@type=\'creativeCommons\']'
      t.open_data_commons :path => '/use/machine[@type=\'openDataCommons\']', :type => 'openDataCommons' do
        t.uri :path => '@uri'
      end
      t.open_data_commons_human :path => '/use/human[@type=\'openDataCommons\']'
    end

    define_template :creative_commons do |xml|
      xml.use {
        xml.human(:type => 'creativeCommons')
        xml.machine(:type => 'creativeCommons', :uri => '')
      }
    end

    define_template :open_data_commons do |xml|
      xml.use {
        xml.human(:type => 'openDataCommons')
        xml.machine(:type => 'openDataCommons', :uri => '')
      }
    end
    
    define_template :copyright do |xml|
      xml.copyright {
        xml.human
      }
    end

    define_template :use_statement do |xml|
      xml.use {
        xml.human(type: 'useAndReproduction')
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
            xml.machine(:type => 'creativeCommons', :uri => '')
            xml.human(:type => 'openDataCommons')
            xml.machine(:type => 'openDataCommons', :uri => '')
          }
          xml.copyright {
            xml.human
          }
        }
      end.doc
    end

    # Ensures that the template is present for the given term
    def initialize_term!(term)
      if find_by_terms(term).length < 1
        ng_xml_will_change!
        add_child_node(ng_xml.root, term)
      end
    end

    # Assigns the defaultObjectRights object's term with the given value. Supports setting value to nil
    def update_term!(term, val)
      ng_xml_will_change!
      if val.blank?
        update_values({ [ term ] => nil })
      else
        initialize_term! term
        update_values({ [ term ] => val })
      end
      normalize!
    end

    def content
      ng_xml.human
    end
    
    # Purge the XML of any empty or duplicate elements -- keeps <rightsMetadata> clean
    def normalize!
      ng_xml_will_change!
      doc = ng_xml
      if doc.xpath('/rightsMetadata/use').length > 1
        # <use> node needs consolidation
        nodeset = doc.xpath('/rightsMetadata/use')
        nodeset[1..-1].each do |node|
          node.children.each do |child|
            nodeset[0] << child # copy over to first <use> element
          end
          node.remove
        end
        fail unless doc.xpath('/rightsMetadata/use').length == 1
      end

      # Call out to the general purpose XML normalization service
      ::Normalizer.new.tap do |norm|
        norm.remove_empty_attributes(doc.root)
        # cleanup ordering is important here
        doc.xpath('//machine/text()').each { |node| node.content = node.content.strip }
        doc.xpath('//human').tap { |nodeset| norm.clean_linefeeds(nodeset) }
        doc.xpath('//human').each { |node| norm.trim_text(node) }
        doc.xpath('//human').each { |node| norm.remove_empty_nodes(node) }
        doc.xpath('/rightsMetadata/copyright').each { |node| norm.remove_empty_nodes(node) }
        doc.xpath('/rightsMetadata/use').each { |node| norm.remove_empty_nodes(node) }        
      end
      content = doc.human
    end
  end
end
