module Dor  
  module Editable
    extend ActiveSupport::Concern
    include ActiveFedora::Relationships

     def add_role role, entity
        xml=self.roleMetadata.ng_xml
        nodes = xml.search('/roleMetadata/role[@type=\''+role+'\']')
        if nodes.length > 0
          node=Nokogiri::XML::Node.new(entity, xml)
          nodes.first.add_child(node)
        else
          node=Nokogiri::XML::Node.new('role', xml)
          node['type']=role
          node.add_child(Nokogiri::XML::Node.new(entity, xml))
          xml.search('/roleMetadata').first.add_child(node)
        end
        self.roleMetadata.content=xml.to_s
      end

      def delete_role role, entity
        xml=self.datastreams['rolesMetadata'].ng_xml
        nodes = xml.search('/roleMetadata/role/'+role)
        if nodes.length > 0
          nodes.first.delete
        end
      end
      def default_collections 
        cols=[]
        #the local-name bit is to ignore namespaces
        self.administrativeMetadata.ng_xml.xpath('/administrativeMetadata/relationships/*[local-name() =\'isMemberOfCollection\']').each do |rel|
          cols << rel['rdf:resource'].split(/\//).last
        end
        cols
      end
  end
end
