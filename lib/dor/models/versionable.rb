module Dor
  module Versionable
    extend ActiveSupport::Concern
    
    included do
      has_metadata :name => 'versionMetadata', :type => Dor::VersionMetadataDS, :label => 'Version Metadata'
    end
    
    def open_new_version
      raise 'Object net yet accessioned' unless(Dor::WorkflowService.get_lifecycle('dor', pid, 'accessioned'))
      raise 'Object already opened for versioning' if(Dor::WorkflowService.get_lifecycle('dor', pid, 'opened'))
    
      datastreams['versionMetadata'].increment_version
      cv = current_version
      # TODO grab workflow XML from reified workflow creation method
      # need to wait till we remove version from the active table
      wf = <<-XML
      <workflow name="versioningWF">
        <process name="start-version" status="completed" lifecycle="opened" version="#{cv}" />
        <process name="submit-version" status="waiting" version="#{cv}" />
        <process name="review-version" status="waiting" version="#{cv}" />
        <process name="accession-initiate" status="waiting" version="#{cv}" />
      </workflow>
      XML
    end
    
    def current_version
      datastreams['versionMetadata'].current_version_id
    end
    
  end
end