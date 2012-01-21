class AdministrativeMetadataDS < ActiveFedora::NokogiriDatastream 

  set_terminology do |t|
    t.root :path => 'administrativeMetadata', :xmlns => '', :namespace_prefix => nil, :index_as => [:not_searchable]
    t.metadata_format :path => 'descMetadata/format', :namespace_prefix => nil
    t.metadata_source :path => 'descMetadata/source', :namespace_prefix => nil
    
    # Placeholders for existing defined stanzas to be fleshed out as needed
    t.contact :namespace_prefix => nil, :index_as => [:not_searchable]
    t.rights :namespace_prefix => nil, :index_as => [:not_searchable]
    t.relationships :namespace_prefix => nil, :index_as => [:not_searchable]
    t.registration :namespace_prefix => nil, :index_as => [:not_searchable] do
      t.agreementId :namespace_prefix => nil
      t.itemTag :namespace_prefix => nil
      t.workflow_id :path => 'workflow/@id', :namespace_prefix => nil, :index_as => [:facetable]
    end
    t.deposit :namespace_prefix => nil, :index_as => [:not_searchable]
    
    t.accessioning :namespace_prefix => nil, :index_as => [:not_searchable] do
      t.workflow_id :path => 'workflow/@id', :namespace_prefix => nil, :index_as => [:facetable]
    end

    t.preservation :namespace_prefix => nil, :index_as => [:not_searchable]
    t.dissemination :namespace_prefix => nil, :index_as => [:not_searchable] do
      t.harvester :namespace_prefix => nil
      t.releaseDelayLimit :namespace_prefix => nil
    end
  end
  
end
