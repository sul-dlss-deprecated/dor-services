# frozen_string_literal: true

module Dor
  module Rightsable
    extend ActiveSupport::Concern

    included do
      has_metadata :name => 'rightsMetadata', :type => Dor::RightsMetadataDS, :label => 'Rights metadata'
    end

    def build_rightsMetadata_datastream(ds)
      content_ds = admin_policy_object.datastreams['defaultObjectRights']
      ds.dsLabel = 'Rights Metadata'
      ds.ng_xml = content_ds.ng_xml.clone
    end

    def world_doc
      Nokogiri::XML::Builder.new do |xml|
        xml.access(:type => 'read') {
          xml.machine { xml.world }
        }
      end.doc
    end
  end
end
