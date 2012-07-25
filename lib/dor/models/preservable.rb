require 'tmpdir'

module Dor
  module Preservable
    extend ActiveSupport::Concern
    
    included do
      has_metadata :name => "provenanceMetadata", :type => ActiveFedora::NokogiriDatastream, :label => 'Provenance Metadata'
      has_metadata :name => "technicalMetadata", :type => ActiveFedora::NokogiriDatastream, :label => 'Technical Metadata', :control_group => 'M'
    end
    
    def build_provenanceMetadata_datastream(workflow_id, event_text)
      ProvenanceMetadataService.add_provenance(self, workflow_id, event_text)
    end

    def build_technicalMetadata_datastream(ds=nil)
      TechnicalMetadataService.add_update_technical_metadata(self)
    end

    def sdr_ingest_transfer(agreement_id)
      SdrIngestService.transfer(self,agreement_id)
    end

  end
end
