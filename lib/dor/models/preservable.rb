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

    def build_technicalMetadata_datastream(ds)
      unless defined? ::JhoveService
        begin
          require 'jhove_service'
        rescue LoadError => e
          puts e.inspect
          raise "jhove-service dependency gem was not found.  Please add it to your Gemfile and run bundle install"
        end
      end
      begin
        content_dir = Druid.new(self.pid).path(Config.sdr.local_workspace_root)
        temp_dir = Dir.mktmpdir(self.pid)
        jhove_service = ::JhoveService.new(temp_dir)
        jhove_output_file = jhove_service.run_jhove(content_dir)
        tech_md_file = jhove_service.create_technical_metadata(jhove_output_file)
        ds.dsLabel = 'Technical Metadata'
        ds.ng_xml = Nokogiri::XML(IO.read(tech_md_file))
        ds.content = ds.ng_xml.to_xml
      ensure
        FileUtils.remove_entry_secure(temp_dir) if File.exist?(temp_dir)
      end
    end

    def sdr_ingest_transfer(agreement_id)
      SdrIngestService.transfer(self,agreement_id)
    end

  end
end
