module Dor  
  module Editable
    extend ActiveSupport::Concern
    include ActiveFedora::Relationships

    def add_roleplayer role, entity, type=:workgroup
      xml=self.roleMetadata.ng_xml
      group='person'
      if type == :workgroup
        group='group'
      end
      nodes = xml.search('/roleMetadata/role[@type=\''+role+'\']')
      if nodes.length > 0
        group_node=Nokogiri::XML::Node.new(group, xml)
        id_node=Nokogiri::XML::Node.new('identifier', xml)
        group_node.add_child(id_node)
        id_node.content=entity
        id_node['type']=type.to_s
        nodes.first.add_child(group_node)
      else
        node=Nokogiri::XML::Node.new('role', xml)
        node['type']=role
        group_node=Nokogiri::XML::Node.new(group, xml)
        node.add_child group_node
        id_node=Nokogiri::XML::Node.new('identifier', xml)
        group_node.add_child(id_node)
        id_node.content=entity
        id_node['type']=type.to_s
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

    def mods_title
      return self.descMetadata.term_values(:title_info, :main_title).first
    end
    def set_mods_title val
      self.descMetadata.update_values({[:title_info, :main_title]=> val})
    end
    def default_collections 
      cols=[]
      #the local-name bit is to ignore namespaces
      self.administrativeMetadata.ng_xml.xpath('/administrativeMetadata/relationships/*[local-name() =\'isMemberOfCollection\']').each do |rel|
        cols << rel['rdf:resource'].split(/\//).last
      end
      cols
    end
    def roles
      roles={}
      self.roleMetadata.ng_xml.search('/roleMetadata/role').each do |role|
        roles[role['type']]=[]
        role.search('identifier').each do |entity|
          roles[role['type']] << entity['type'] + ':' + entity.text()
        end
      end
      roles
    end
    
    def use_statement
      use=self.defaultObjectRights.use_statement.first
      use ? use : ''
    end
    def set_use_statement val
      self.defaultObjectRights.update_values({[:use_statement] => val})
    end
    def copyright_statement
      copy=self.defaultObjectRights.copyright.first
      copy ? copy : ''
    end
    def set_copyright_statement val
      self.defaultObjectRights.update_values({[:copyright] => val})
    end
    def creative_commons_license
      cc = self.defaultObjectRights.creative_commons.first
      cc ? cc : ''
    end
    def set_creative_commons_license val
      if not creative_commons_license
        #add the nodes
       self.defaultObjectRights.add_child_node(self.defaultObjectRights.ng_xml.root, :creative_commons)
      end
      self.defaultObjectRights.update_values({[:creative_commons] => val})
    end
    def default_rights
      xml=self.defaultObjectRights.ng_xml
      if xml.search('//rightsMetadata/access[@type=\'read\']/machine/group').length == 1
        'Stanford'
      else
        if xml.search('//rightsMetadata/access[@type=\'read\']/machine/world').length ==1
          'World'
        else
          if xml.search('//rightsMetadata/access[@type=\'discover\']/machine/none').length == 1
            'Dark'
          else
            'None'
          end
        end
      end
    end
    def desc_metadata_format
      format = self.administrativeMetadata.metadata_format.first
      format ? format : ''
    end
    def set_desc_metadata_format format
      #create the node if it isnt there already
      if not self.administrativeMetadata.metadata_format.first
        self.administrativeMetadata.add_child_node(self.administrativeMetadata.ng_xml.root, :metadata_format)
      end
      self.administrativeMetadata.update_values({[:metadata_format] => format})
    end
    def default_workflows
      xml=self.administrativeMetadata.ng_xml
      nodes=xml.search('//registration/workflow')
      if nodes.length > 0
        wfs=[]
        nodes.each do |node|
          wfs << node['id']
        end
        wfs
      else
        []
      end      
    end
    def agreement
     agr = self.administrativeMetadata.term_values(:registration, :agreementId).first
     agr ? agr : ''
    end
  end
end
