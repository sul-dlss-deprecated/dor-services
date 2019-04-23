# frozen_string_literal: true

module Dor
  module Governable
    extend ActiveSupport::Concern

    def reset_to_apo_default
      rightsMetadata.content = admin_policy_object.rightsMetadata.ng_xml
    end

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
      collection =
        case collection_or_druid
        when String
          Dor::Collection.find(collection_or_druid)
        when Dor::Collection
          collection_or_druid
        end
      collections << collection
      sets << collection
    end

    def remove_collection(collection_or_druid)
      collection =
        case collection_or_druid
        when String
          Dor::Collection.find(collection_or_druid)
        when Dor::Collection
          collection_or_druid
        end

      collections.delete(collection)
      sets.delete(collection)
    end

    # set the rights metadata datastream to the content of the APO's default object rights
    def reapplyAdminPolicyObjectDefaults
      rightsMetadata.content = admin_policy_object.datastreams['defaultObjectRights'].content
    end
  end
end
