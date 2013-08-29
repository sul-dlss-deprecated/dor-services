module Dor  
  module Governable
    extend ActiveSupport::Concern
    include ActiveFedora::Relationships

    included do
      belongs_to 'admin_policy_object', :property => :is_governed_by, :class_name => "Dor::AdminPolicyObject"
      has_and_belongs_to_many :collections, :property => :is_member_of_collection, :class_name => "Dor::Collection"
      has_and_belongs_to_many :sets, :property => :is_member_of, :class_name => "Dor::Collection"
    end

    def initiate_apo_workflow(name)
      self.initialize_workflow(name, 'dor', !self.new_object?)
    end

    def reset_to_apo_default()
      rights_metadata_ds = self.rightsMetadata
      #get the apo for this object
      apo_druid=obj.identityMetadata.adminPolicy.first
      apo_obj=Dor::Item.find(apo_druid, :lightweight => true)
      rights_metadata_ds.content=apo_obj.rightsMetadata.ng_xml
    end

    def set_read_rights(rights)
      return if not ['world','stanford','none', 'dark'].include? rights
      rights_metadata_ds = self.rightsMetadata
      rights_xml=rights_metadata_ds.ng_xml
      if(rights_xml.search('//rightsMetadata/access[@type=\'read\']').length==0)
        raise ('The rights metadata stream doesnt contain an entry for machine read permissions. Consider populating it from the APO before trying to change it.')
      end
      rights_xml.search('//rightsMetadata/access[@type=\'discover\']/machine').each do |node|
        node.children.remove
        if rights=='dark'
            world_node=Nokogiri::XML::Node.new('none',rights_xml)
            node.add_child(world_node)
        else
            world_node=Nokogiri::XML::Node.new('world',rights_xml)
          node.add_child(world_node)
        end
      end
      rights_xml.search('//rightsMetadata/access[@type=\'read\']').each do |node|
        node.children.remove
        machine_node=Nokogiri::XML::Node.new('machine',rights_xml)
        if(rights=='world')
          world_node=Nokogiri::XML::Node.new(rights,rights_xml)
          node.add_child(machine_node)
          machine_node.add_child(world_node)
        end
        if rights=='stanford'
          world_node=Nokogiri::XML::Node.new(rights,rights_xml)
          node.add_child(machine_node)
          group_node=Nokogiri::XML::Node.new('group',rights_xml)
          group_node.content="Stanford"
          node.add_child(machine_node)
          machine_node.add_child(group_node)
        end
        if rights=='none' or rights == 'dark'
          none_node=Nokogiri::XML::Node.new('none',rights_xml)
          node.add_child(machine_node)
          machine_node.add_child(none_node)
        end
      end 
    end

    def add_collection(collection_or_druid)
      collection = case collection_or_druid
        when String
          Dor::Collection.find(collection_or_druid)
        when Dor::Collection
          collection_or_druid
      end
      self.collections << collection
      self.sets << collection
    end 
    
    def remove_collection(collection_or_druid)

      collection = case collection_or_druid
        when String
          Dor::Collection.find(collection_or_druid)
        when Dor::Collection
          collection_or_druid
      end

      self.collections.delete(collection)
      self.sets.delete(collection)
    end
    #set the rights metadata datastream to the content of the APO's default object rights
    def reapplyAdminPolicyObjectDefaults
      rightsMetadata.content=admin_policy_object.datastreams['defaultObjectRights'].content
    end
    
    def groups_which_manage_item
      ['dor-administrator','dor-apo-manager', 'dor-apo-depositor']
    end
    def groups_which_manage_desc_metadata
      ['dor-administrator','dor-apo-manager', 'dor-apo-depositor', 'dor-apo-metadata']
    end
    def groups_which_manage_system_metadata
      ['dor-administrator','dor-apo-manager', 'dor-apo-depositor']
    end
    def groups_which_manage_content
      ['dor-administrator','dor-apo-manager', 'dor-apo-depositor']    
    end
    def groups_which_manage_rights
      ['dor-administrator','dor-apo-manager', 'dor-apo-depositor']
    end
    def groups_which_manage_embargo
      ['dor-administrator','dor-apo-manager', 'dor-apo-depositor']    
    end
    def groups_which_view_content
      ['dor-administrator','dor-apo-manager', 'dor-apo-depositor', 'dor-viewer']    
    end
    def groups_which_view_metadata
      ['dor-administrator','dor-apo-manager', 'dor-apo-depositor', 'dor-viewer']    
    end
    def intersect arr1, arr2
      return (arr1 & arr2).length > 0
    end
    def can_manage_item? roles
      intersect roles, groups_which_manage_item
    end
    def can_manage_desc_metadata? roles
      intersect roles, groups_which_manage_desc_metadata
    end
    def can_manage_system_metadata? roles
      intersect roles, groups_which_manage_system_metadata
    end
    def can_manage_content? roles
      intersect roles, groups_which_manage_content
    end
    def can_manage_rights? roles
      intersect roles, groups_which_manage_rights
    end
    def can_manage_embargo? roles
      intersect roles, groups_which_manage_embargo
    end
    def can_view_content? roles
      intersect roles, groups_which_view_content
    end
    def can_view_metadata? roles
      intersect roles, groups_which_view_metadata
    end
  end
end