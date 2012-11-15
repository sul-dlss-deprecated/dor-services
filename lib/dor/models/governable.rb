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
      self.initialize_workflow(name, 'dor', !self.new_object?)
    end
    def ato_solr(solr_doc=Hash.new, *args)
    xml='<rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" 
          xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:hydra="http://projecthydra.org/ns/relations#">
          <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
            <fedora-model:hasModel rdf:resource="info:fedora/testObject"/>
            <hydra:isGovernedBy rdf:resource="info:fedora/druid:fg890hi1234"/>
          </rdf:Description>
        </rdf:RDF>'
        
    puts solr_doc.inspect
      rels_doc = Nokogiri::XML(xml)#(self.datastreams['RELS-EXT'].content)
       collections=rels_doc.search('//rdf:RDF/rdf:Description/fedora:isMemberOfCollection','fedora' => 'info:fedora/fedora-system:def/relations-external#', 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' 	)
       collections.each do |collection_node| 
        druid=collection_node['resource']
        druid=druid.gsub('info:fedora/','')
        collection_object=Dor.find(druid)
        add_solr_value(solr_doc, "collection_title", collection_object.label, :string, [:searchable, :facetable])
       end
       
       apos=rels_doc.search('//rdf:RDF/rdf:Description/hydra:isGovernedBy','hydra' => 'http://projecthydra.org/ns/relations#', 'fedora' => 'info:fedora/fedora-system:def/relations-external#', 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' 	)
       apos.each do |apo|node|
        druid=apo_node['resource']
        druid=druid.gsub('info:fedora/','')
        apo_object=Dor.find(druid)
        add_solr_value(solr_doc, "apo_title", apo_object.label, :string, [:searchable, :facetable])
       end
       solr_doc
    puts solr_doc.inspect
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