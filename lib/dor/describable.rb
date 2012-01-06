module Dor
  module Describable
    extend ActiveSupport::Concern
    
    included do
      has_metadata :name => "descMetadata", :type => ActiveFedora::NokogiriDatastream, :label => 'Descriptive Metadata', :control_group => 'M'
    end

    def fetch_descMetadata_datastream
      candidates = self.identity_metadata.otherIds.collect { |oid| oid.to_s }
      metadata_id = Dor::MetadataService.resolvable(candidates).first
      unless metadata_id.nil?
        return Dor::MetadataService.fetch(metadata_id.to_s)
      else
        return nil
      end
    end

    def build_descMetadata_datastream(ds)
      content = fetch_descMetadata_datastream
      unless content.nil?
        ds.label = 'Descriptive Metadata'
        ds.ng_xml = Nokogiri::XML(content)
        ds.ng_xml.normalize_text!
      end
    end
    
    # Generates Dublin Core from the MODS in the descMetadata datastream using the LoC mods2dc stylesheet
    #   Should not be used for the Fedora DC datastream
    # @raise [Exception] Raises an Exception if the generated DC is empty or has no children
    def generate_dublin_core
      apo = self.admin_policy_object
      format = begin
        apo.datastreams['administrativeMetadata'].ng_xml.at('/administrativeMetadata/descMetadata/format').text.downcase 
      rescue 
        'mods'
      end
      xslt = Nokogiri::XSLT(File.new(File.expand_path(File.dirname(__FILE__) + "/#{format}2dc.xslt")) )
      dc_doc = xslt.transform(self.datastreams['descMetadata'].ng_xml)
      if(dc_doc.root.nil? || dc_doc.root.children.size == 0)
        raise "Dor::Item#generate_dublin_core produced incorrect xml:\n#{dc_doc.to_xml}"
      end
      dc_doc
    end
    
  end
end