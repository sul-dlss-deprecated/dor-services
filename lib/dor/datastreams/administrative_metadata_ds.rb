module Dor
class AdministrativeMetadataDS < ActiveFedora::OmDatastream

  set_terminology do |t|
    t.root :path => 'administrativeMetadata', :index_as => [:not_searchable]
    t.metadata_format :path => 'descMetadata/format'
    t.admin_metadata_format :path => 'descMetadata/format', :index_as => [:symbol]
    t.metadata_source :path => 'descMetadata/source'. :index_as => [:symbol]
    t.descMetadata do
      t.source
      t.format
    end
    # Placeholders for existing defined stanzas to be fleshed out as needed
    t.contact :index_as => [:not_searchable]
    t.rights :index_as => [:not_searchable]
    t.relationships :index_as => [:not_searchable]
    t.registration :index_as => [:not_searchable] do
      t.agreementId
      t.itemTag
      t.workflow_id :path => 'workflow/@id', :index_as => [:symbol, :facetable]
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
    t.defaults do
      t.initiate_workflow :path => 'initiateWorkflow' do
        t.lane :path => { :attribute => 'lane' }
      end
      t.shelving :path => 'shelving' do
        t.path :path => { :attribute => 'path'}
      end
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
    xml.administrativeMetadata {
      xml.registration{
        xml.agreementId
      }
    }
  end

  define_template :metadata_format do |xml|
     xml.descMetadata{
       xml.format
     }
  end

  define_template :metadata_source do |xml|
    xml.administrativeMetadata{
      xml.descMetadata{
       xml.source
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
      xml.administrativeMetadata{ }
    end.doc
  end

  #################################################################################
  # Convenience methods to get and set properties
  # Hides complexity/verbosity of OM TermOperators for simple, non-repeating values
  #################################################################################

  def default_workflow_lane= lane
    self.defaults.initiate_workflow.lane = lane
  end

  def default_workflow_lane
    self.defaults.initiate_workflow.lane.first
  end

  def default_shelving_path= path
    self.defaults.shelving.path = path
  end

  def default_shelving_path
    self.defaults.shelving.path.first
  end

end

end
