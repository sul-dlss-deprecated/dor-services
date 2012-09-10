module Dor
  class DescriptiveMetadataService
    class << self
      def update_title(druid,new_title)
        if not update_simple_field(druid,'mods:mods/mods:titleInfo/mods:title',new_title)
				  raise 'Descriptive metadata has no title to update!'
				end
      end
      def update_subtitle(druid,new_title)
        update_simple_field(druid,'subTitle',new_title)
      end
      def add_identifier(druid,type, value)
        obj=Dor::Item.find(druid, :lightweight => true)
        ds_xml=obj.descMetadata.ng_xml
				ds_xml.search('//mods:mods','mods' => 'http://www.loc.gov/mods/v3').each do |node|
        new_node=Nokogiri::XML::Node.new('identifier',ds_xml) #this ends up being mods:identifier without having to specify the namespace
				new_node['type']=type
        new_node.content=value
        node.add_child(new_node)
        ds_xml.inspect
        end
      end
			def delete_identifier(druid,type,value)
				obj=Dor::Item.find(druid, :lightweight => true)
        ds_xml=obj.descMetadata.ng_xml
        ds_xml.search('//mods:identifier','mods' => 'http://www.loc.gov/mods/v3').each do |node|	
				  if node.content == value
						node.remove
						return true	
					end
				end
				return false
			end
      private
      #generic updater useful for updating things like title or subtitle which can only have a single occurance and must be present
      def update_simple_field(druid,field,new_val)
        obj=Dor::Item.find(druid, :lightweight => true)
        ds_xml=obj.descMetadata.ng_xml
        ds_xml.search('//'+field,'mods' => 'http://www.loc.gov/mods/v3').each do |node|
          node.content=new_val
					return true
        end
				return false
      end
    end
  end
end
