module Dor
  module Geoable
    extend ActiveSupport::Concern
    include SolrDocHelper

    class CrosswalkError < Exception; end

    included do
      has_metadata  :name => 'geoMetadata',
                    :type => Dor::GeoMetadataDS,
                    :label => 'Geographic Information Metadata in ISO 19139',
                    :control_group => 'M'
    end

    # @return [String] XML
    def fetch_geoMetadata_datastream
      candidates = datastreams['identityMetadata'].otherId.collect { |oid| oid.to_s }
      metadata_id = Dor::MetadataService.resolvable(candidates).first
      unless metadata_id.nil?
        return Dor::MetadataService.fetch(metadata_id.to_s)
      else
        return nil
      end
    end

    def build_geoMetadata_datastream(ds)
      content = fetch_geoMetadata_datastream
      unless content.nil?
        ds.dsLabel = label
        ds.ng_xml = Nokogiri::XML(content)
        ds.ng_xml.normalize_text!
        ds.content = ds.ng_xml.to_xml
      end
    end
  end
end
