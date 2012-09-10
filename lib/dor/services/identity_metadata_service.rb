module Dor
  class IdentityMetadataService
    class << self
      def update_source_id(druid,source_id)
        obj=Dor::Item.find(druid, :lightweight => true)
        identity_metadata_ds = obj.identityMetadata
        identity_metadata_ds.sourceId = source_id
      end

      def add_other_Id(druid, val)
        obj=Dor::Item.find(druid, :lightweight => true)
        node_name=val.split(/:/).first
        if obj.identityMetadata.otherId(node_name).length>0        
          raise 'There is an existing entry for '+node_name+', consider using update_other_identifier.'
        end
        identity_metadata_ds = obj.identityMetadata
        identity_metadata_ds.add_otherId(val)
      end

      def update_other_Id(druid, val)
        obj=Dor::Item.find(druid, :lightweight => true)
        identity_metadata_ds = obj.identityMetadata
        ds_xml=identity_metadata_ds.ng_xml
        #split the thing they sent in to find the node name
        node_name=val.split(/:/).first
        new_val=val.split(/:/).last
        updated=false
        ds_xml.search('//otherId[@name=\''+node_name+'\']').each do |node|
          node.content=new_val
          updated=true
          obj.identityMetadata.dirty=true
        end
        return updated
      end
 
      def remove_other_Id(druid, val)
        obj=Dor::Item.find(druid, :lightweight => true)
        identity_metadata_ds = obj.identityMetadata
        ds_xml=identity_metadata_ds.ng_xml
        #split the thing they sent in to find the node name
        node_name=val.split(/:/).first  
        removed=false
        ds_xml.search('//otherId[@name=\''+node_name+'\']').each do |node|
          if node.content===val.split(/:/).last
            node.remove
            removed=true
            identity_metadata_ds.dirty=true
          end
        end
        return removed
      end
      
      def add_tag(druid,tag)
        obj=Dor::Item.find(druid, :lightweight => true)
        identity_metadata_ds = obj.identityMetadata
        prefix=tag.split(/:/).first
        identity_metadata_ds.tags.each do |existing_tag|
          if existing_tag.split(/:/).first ==prefix 
            raise 'An existing tag ('+existing_tag+') has the same prefix, consider using update_tag?'
          end
        end
        identity_metadata_ds.add_value(:tag,tag)
      end
      
      def remove_tag(druid,tag)
        obj=Dor::Item.find(druid, :lightweight => true)
        identity_metadata_ds = obj.identityMetadata
        ds_xml=identity_metadata_ds.ng_xml
        removed=false
        ds_xml.search('//tag').each do |node|
          if node.content===tag
            node.remove
            removed=true
            obj.identityMetadata.dirty=true
          end
        end
        return removed
      end
      
      def update_tag(druid,old_tag,new_tag)
        obj=Dor::Item.find(druid, :lightweight => true)
        identity_metadata_ds = obj.identityMetadata
        ds_xml=identity_metadata_ds.ng_xml
        updated=false
        ds_xml.search('//tag').each do |node|
          if node.content==old_tag
            node.content=new_tag
            updated = true
            obj.identityMetadata.dirty=true
          end
        end
        return updated 
      end
    end
  end
end