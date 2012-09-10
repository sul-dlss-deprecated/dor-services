module Dor
  class RightsMetadataService
    class << self
      #set the object rights metadata to match the apo defaults
      def reset_to_apo_default(druid)
        obj=Dor::Item.find(druid, :lightweight => true)
        rights_metadata_ds = obj.rightsMetadata
        #get the apo for this object
        apo_druid=obj.identityMetadata.adminPolicy.first
        apo_obj=Dor::Item.find(apo_druid, :lightweight => true)
        rights_metadata_ds.content=apo_obj.rightsMetadata.ng_xml
      end
      
      def set_read_rights(druid,rights)
        if not ['world','stanford','none'].include? rights
          raise "Unknown rights setting \'" + rights + "\' when calling #{self.name}.set_read_rights"
        end
        obj=Dor::Item.find(druid, :lightweight => true)
        rights_metadata_ds = obj.rightsMetadata
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
    end
  end
end
