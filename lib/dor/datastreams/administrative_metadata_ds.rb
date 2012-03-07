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
    end
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
  
end
end