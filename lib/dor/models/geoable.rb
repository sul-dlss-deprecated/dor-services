module Dor
  module Geoable
    extend ActiveSupport::Concern

    class CrosswalkError < Exception; end

    included do
      has_metadata  :name => 'geoMetadata',
                    :type => Dor::GeoMetadataDS,
                    :label => 'Geographic Information Metadata in ISO 19139',
                    :control_group => 'M'
    end

    # @return [String, nil] XML
    def fetch_geoMetadata_datastream
      candidates = self.datastreams['identityMetadata'].otherId.collect { |oid| oid.to_s }
      metadata_id = Dor::MetadataService.resolvable(candidates).first
      return nil if metadata_id.nil?
      return Dor::MetadataService.fetch(metadata_id.to_s)
    end

    def build_geoMetadata_datastream(ds)
      content = fetch_geoMetadata_datastream
      return nil if content.nil?
      ds.dsLabel = self.label
      ds.ng_xml = Nokogiri::XML(content)
      ds.ng_xml.normalize_text!
      ds.content = ds.ng_xml.to_xml
    end
  end
end
