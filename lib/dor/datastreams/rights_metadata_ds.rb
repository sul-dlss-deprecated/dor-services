module Dor
  class RightsMetadataDS < ActiveFedora::OmDatastream
    require 'dor/rights_auth'

    attr_writer :dra_object

    # This is separate from default_object_rights because
    # (1) we cannot default to such a permissive state
    # (2) this is real, not default

    set_terminology do |t|
      t.root :path => 'rightsMetadata', :index_as => [:not_searchable]
      t.copyright :path => 'copyright/human', :index_as => [:facetable]
      t.use_statement :path => '/use/human[@type=\'useAndReproduction\']', :index_as => [:facetable]

      t.use do
        t.machine
        t.human
      end

      t.creative_commons :path => '/use/machine', :type => 'creativeCommons'
      t.creative_commons_human :path => '/use/human[@type=\'creativeCommons\']'
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
          xml.access(:type => 'discover'){
            xml.machine{ xml.none }
          }
          xml.access(:type => 'read'){
            xml.machine{ xml.none }   # dark default
          }
          xml.use{
            xml.human(:type => 'useAndReproduction')
            xml.human(:type => "creativeCommons")
            xml.machine(:type => "creativeCommons")
          }
          xml.copyright{ xml.human }
        }
      end.doc
    end

    def dra_object
      @dra_object ||= Dor::RightsAuth.parse(self.ng_xml, true)
    end

    def to_solr(solr_doc=Hash.new, *args)
      super(solr_doc, *args)
      dra = self.dra_object
      solr_doc['rights_primary_ssi'] = dra.index_elements[:primary]
      solr_doc['rights_errors_ssim'] = dra.index_elements[:errors] if dra.index_elements[:errors].size > 0
      solr_doc['rights_characteristics_ssim'] = dra.index_elements[:terms] if dra.index_elements[:terms].size > 0
      solr_doc
    end

  end #class
end
