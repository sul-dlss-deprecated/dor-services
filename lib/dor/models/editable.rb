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

    def mods_title
      node=self.descMetadata.ng_xml.search('//mods:mods/mods:titleInfo/mods:title','mods' => 'http://www.loc.gov/mods/v3')
      if node.length == 1
        node.first.text()
      else
        ''
      end
    end
    def set_mods_title

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
      node=self.defaultObjectRights.ng_xml.search('//use/human[@type=\'useAndReproduction\']')
      if node.length ==1
        node.first.text()
      else
        ''
      end
    end
    def copyright_statement
      node=self.defaultObjectRights.ng_xml.search('//copyright/human')
      if node.length == 1
        node.first.text()
      else
        ''
      end
    end
    def creative_commons_license
      node=self.defaultObjectRights.ng_xml.search('//use/machine[@type=\'creativeCommons\']')
      if node.length == 1
        node.first.text()
      else
        ''
      end
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
      xml=self.administrativeMetadata.ng_xml
      node=xml.search('//descMetadata/format')
      if node.length == 1
        node.first.text()
      else
        ''
      end
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
  end
end
