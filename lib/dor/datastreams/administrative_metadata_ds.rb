module Dor
class AdministrativeMetadataDS < ActiveFedora::NokogiriDatastream 

  set_terminology do |t|
    t.root :path => 'administrativeMetadata', :index_as => [:not_searchable]
    t.metadata_format :path => 'descMetadata/format'
    t.metadata_source :path => 'descMetadata/source'
    
    # Placeholders for existing defined stanzas to be fleshed out as needed
    t.contact :index_as => [:not_searchable]
    t.rights :index_as => [:not_searchable]
    t.relationships :index_as => [:not_searchable]
    t.registration :index_as => [:not_searchable] do
      t.agreementId
      t.itemTag
      t.workflow_id :path => 'workflow/@id', :index_as => [:facetable]
      t.default_collection :path => 'collection/@id'
    end
    t.workflow :path => 'registration/workflow'
    t.deposit :index_as => [:not_searchable]
    
    t.accessioning :index_as => [:not_searchable] do
      t.workflow_id :path => 'workflow/@id', :index_as => [:facetable]
    end

    t.preservation :index_as => [:not_searchable]
    t.dissemination :index_as => [:not_searchable] do
      t.harvester
      t.releaseDelayLimit
    end
  end
  define_template :default_collection do |xml|
  xml.administrativeMetadata{
    xml.registration{
      xml.collection(:id => '')
    }
  }
  end
  define_template :agreementId do |xml|
    xml.administrativeMetadata{
      xml.registration{
        xml.agreementId
      }
    }
  end
  define_template :metadata_format do |xml|
     xml.administrativeMetadata {
       xml.descMetadata{
       xml.format
     }
     }
   end
   define_template :registration do |xml|
      xml.administrativeMetadata {
        xml.registration{
          xml.workflow(:id=> '')
        }
      }
    end
    define_template :default_collection do |xml|
        xml.administrativeMetadata {
          xml.registration{
            xml.collection
        }
        }
      end
      def self.xml_template
        Nokogiri::XML::Builder.new do |xml|
          xml.administrativeMetadata{
          }
        end.doc
      end
end

end