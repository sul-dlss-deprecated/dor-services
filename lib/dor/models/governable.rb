module Dor  
  module Governable
    extend ActiveSupport::Concern
    include ActiveFedora::Relationships
    
    included do
      has_relationship 'admin_policy_object', :is_governed_by
      has_relationship 'collection', :is_member_of_collection
      has_relationship 'set', :is_member_of
    end
  
    def initiate_apo_workflow(name)
      self.initialize_workflow(name)
    end
	def reset_to_apo_default()
        rights_metadata_ds = self.rightsMetadata
        #get the apo for this object
        apo_druid=obj.identityMetadata.adminPolicy.first
        apo_obj=Dor::Item.find(apo_druid, :lightweight => true)
        rights_metadata_ds.content=apo_obj.rightsMetadata.ng_xml
      end
      
      def set_read_rights(rights)
        if not ['world','stanford','none'].include? rights
          raise "Unknown rights setting \'" + rights + "\' when calling #{self.name}.set_read_rights"
        end
        rights_metadata_ds = self.rightsMetadata
        rights_xml=rights_metadata_ds.ng_xml
        if(rights_xml.search('//rightsMetadata/access[@type=\'read\']').length==0)
          raise ('The rights metadata stream doesnt contain an entry for machine read permissions. Consider populating it from the APO before trying to change it.')
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
          if rights=='none'
              none_node=Nokogiri::XML::Node.new('none',rights_xml)
              node.add_child(machine_node)
              machine_node.add_child(none_node)
          end
        end 
        rights_metadata_ds.dirty=true
      end
  
  def add_collection(collection_druid)
			self.add_relationship_by_name('collection','info:fedora/'+collection_druid)
  end 
  def remove_collection(collection_druid)
	self.remove_relationship_by_name('collection','info:fedora/'+collection_druid)
  end
end
end