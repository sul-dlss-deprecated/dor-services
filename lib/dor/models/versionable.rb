module Dor
  module Versionable
    extend ActiveSupport::Concern
    include Processable
    include Upgradable
    
    included do
      has_metadata :name => 'versionMetadata', :type => Dor::VersionMetadataDS, :label => 'Version Metadata', :autocreate => true
    end
    
    def open_new_version
      raise Dor::Exception, 'Object net yet accessioned' unless(Dor::WorkflowService.get_lifecycle('dor', pid, 'accessioned'))
      raise Dor::Exception, 'Object already opened for versioning' if(Dor::WorkflowService.get_active_lifecycle('dor', pid, 'opened'))

      ds = datastreams['versionMetadata']
      ds.increment_version
      ds.content = ds.ng_xml.to_s
      ds.save unless self.new_object? 
      initialize_workflow('versioningWF')
    end
    
    def current_version
      datastreams['versionMetadata'].current_version_id
    end
    
  end
end