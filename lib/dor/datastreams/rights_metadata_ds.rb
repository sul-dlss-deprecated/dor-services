module Dor
class RightsMetadataDS < ActiveFedora::OmDatastream
  include SolrDocHelper
  require 'dor/rights_auth'

  # This is separate from default_object_rights because
  # (1) we cannot default to such a permissive state
  # (2) this is real, not default

  def self.xml_template
    Nokogiri::XML::Builder.new do |xml|
      xml.rightsMetadata{
        xml.access(:type => 'discover'){
          xml.machine{ xml.none }
        }
        xml.access(:type => 'read'){
          xml.machine{ xml.none }
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

  set_terminology do |t|
    t.root          :path => 'rightsMetadata',                           :index_as => [:not_searchable]
    t.copyright     :path => '/copyright/human',                         :index_as => [:facetable]
    t.use_statement :path => '/use/human[@type=\'useAndReproduction\']', :index_as => [:facetable]

    t.use do
      t.machine
      t.human
    end

    t.creative_commons       :path => '/use/machine', :type => 'creativeCommons'
    t.creative_commons_human :path => '/use/human[@type=\'creativeCommons\']'
  end

  define_template :creative_commons do |xml|
    xml.use {
      xml.human(:type => "creativeCommons")
      xml.machine(:type => "creativeCommons")
    }
  end

  def to_solr(solr_doc=Hash.new, *args)
    super(solr_doc, *args)
    if digital_object.respond_to?(:profile)
      digital_object.profile.each_pair do |property,value|
        add_solr_value(solr_doc, property.underscore, value, property =~ /Date/ ? :date : :string, [:searchable])
      end
    end
    if sourceId.present?
      (name,id) = sourceId.split(/:/,2)
      add_solr_value(solr_doc, "dor_id", id, :string, [:searchable])
      add_solr_value(solr_doc, "identifier", sourceId, :string, [:searchable])
      add_solr_value(solr_doc, "source_id", sourceId, :string, [:searchable])
    end
    solr_doc
  end
end #class
end
