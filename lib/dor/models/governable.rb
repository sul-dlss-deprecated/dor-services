module Dor
  module Governable
    extend ActiveSupport::Concern
    include Rightsable

    included do
      belongs_to :admin_policy_object, :property => :is_governed_by, :class_name => 'Dor::AdminPolicyObject'
      has_and_belongs_to_many :collections, :property => :is_member_of_collection, :class_name => 'Dor::Collection'
      has_and_belongs_to_many :sets, :property => :is_member_of, :class_name => 'Dor::Collection'
    end

    def initiate_apo_workflow(name)
      create_workflow(name, !self.new_object?)
    end

    # Returns the default lane_id from the item's APO.  Will return 'default' if the item does not have
    #   and APO, or if the APO does not have a default_lane
    # @return [String] the lane id
    def default_workflow_lane
      return 'default' if admin_policy_object.nil?  # TODO: log warning?

      admin_md = admin_policy_object.datastreams['administrativeMetadata']
      return 'default' unless admin_md.respond_to? :default_workflow_lane
      lane = admin_md.default_workflow_lane
      return 'default' if lane.nil? || lane.strip == ''
      lane
    end

    def reset_to_apo_default
      rightsMetadata.content = admin_policy_object.rightsMetadata.ng_xml.to_s
    end

    def set_read_rights(rights)
      rightsMetadata.set_read_rights(rights)
    end

    def add_collection(collection_or_druid)
      collection = case collection_or_druid
        when String
          Dor::Collection.find(collection_or_druid)
        when Dor::Collection
          collection_or_druid
      end
      collections << collection
      sets << collection
    end

    def remove_collection(collection_or_druid)
      collection = case collection_or_druid
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

    def rights
      return nil unless self.respond_to? :rightsMetadata
      return nil if rightsMetadata.nil?
      xml = rightsMetadata.ng_xml
      return nil if xml.search('//rightsMetadata').length != 1      # ORLY?
      if xml.search('//rightsMetadata/access[@type=\'read\']/machine/group').length == 1
        'Stanford'
      elsif xml.search('//rightsMetadata/access[@type=\'read\']/machine/world').length == 1
        'World'
      elsif xml.search('//rightsMetadata/access[@type=\'discover\']/machine/none').length == 1
        'Dark'
      else
        'None'
      end
    end
  end
end
