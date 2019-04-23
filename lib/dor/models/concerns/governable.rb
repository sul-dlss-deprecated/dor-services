# frozen_string_literal: true

module Dor
  # Relationships to collections and codified administrative policies.
  module Governable
    extend ActiveSupport::Concern

    def set_read_rights(rights)
      rightsMetadata.set_read_rights(rights)
      unshelve_and_unpublish if rights == 'dark'
    end

    def unshelve_and_unpublish
      if respond_to? :contentMetadata
        content_ds = datastreams['contentMetadata']
        unless content_ds.nil?
          content_ds.ng_xml.xpath('/contentMetadata/resource//file').each_with_index do |file_node, index|
            content_ds.ng_xml_will_change! if index == 0
            file_node['publish'] = 'no'
            file_node['shelve'] = 'no'
          end
        end
      end
    end

    def add_collection(collection_or_druid)
      collection_manager.add(collection_or_druid)
    end

    def remove_collection(collection_or_druid)
      collection_manager.remove(collection_or_druid)
    end

    def collection_manager
      CollectionService.new(self)
    end

    # set the rights metadata datastream to the content of the APO's default object rights
    def reapplyAdminPolicyObjectDefaults
      rightsMetadata.content = admin_policy_object.datastreams['defaultObjectRights'].content
    end
  end
end
