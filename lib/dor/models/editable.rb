module Dor
  module Editable
    extend ActiveSupport::Concern
    include ActiveFedora::Relationships

    included do
      belongs_to 'agreement_object', :property => :referencesAgreement, :class_name => "Dor::Item"
    end

    def to_solr(solr_doc = Hash.new, *args)
      super(solr_doc, *args)
      add_solr_value(solr_doc, "default_rights", default_rights, :string, [:facetable])
      add_solr_value(solr_doc, "agreement", agreement, :string, [:facetable]) if agreement_object
      solr_doc
    end
    #Adds a person or group to a role in the APO role metadata datastream
    #
    #@param role [String] the role the group or person will be filed under, ex. dor-apo-manager
    #@param entity [String] the name of the person or group, ex dlss:developers or sunetid:someone
    #@param type [Symbol] :workgroup for a group or :person for a person
    def add_roleplayer role, entity, type = :workgroup
      xml=roleMetadata.ng_xml
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
      roleMetadata.content=xml.to_s
    end
    #remove all people groups and roles from the APO role metadata datastream
    def purge_roles
      xml=roleMetadata.ng_xml
      nodes = xml.search('/roleMetadata/role')
      nodes.each do |node|
        node.remove
      end
    end

    def mods_title
      descMetadata.term_values(:title_info, :main_title).first
    end
    def mods_title=(val)
      descMetadata.update_values({[:title_info, :main_title] => val})
    end
    #get all collections listed for this APO, used during registration
    #@return [Array] array of pids
    def default_collections
      administrativeMetadata.term_values(:registration, :default_collection)
    end
    #Add a collection to the listing of collections for items governed by this apo.
    #@param val [String] pid of the collection, ex. druid:ab123cd4567
    def add_default_collection val
      ds=administrativeMetadata
      xml=ds.ng_xml
      reg=xml.search('//administrativeMetadata/registration').first
      unless reg
        reg=Nokogiri::XML::Node.new('registration',xml)
        xml.search('/administrativeMetadata').first.add_child(reg)
      end
      node=Nokogiri::XML::Node.new('collection',xml)
      node['id']=val
      reg.add_child(node)
      administrativeMetadata.content=xml.to_s
    end

    def remove_default_collection val
      ds=administrativeMetadata
      xml=ds.ng_xml
      xml.search('//administrativeMetadata/registration/collection[@id=\''+val+'\']').remove
      administrativeMetadata.content=xml.to_s
    end
    #Get all roles defined in the role metadata, and the people or groups in those roles. Groups are prefixed with 'workgroup:'
    #@return [Hash] role => ['person','group'] ex. {"dor-apo-manager" => ["workgroup:dlss:developers", "sunetid:lmcrae"]
    def roles
      roles={}
      roleMetadata.ng_xml.search('/roleMetadata/role').each do |role|
        roles[role['type']]=[]
        role.search('identifier').each do |entity|
          roles[role['type']] << entity['type'] + ':' + entity.text()
        end
      end
      roles
    end
    def metadata_source
      administrativeMetadata.metadata_source.first
    end
    def metadata_source=(val)
      if administrativeMetadata.descMetadata.nil?
        administrativeMetadata.add_child_node(administrativeMetadata, :descMetadata)
      end
      administrativeMetadata.update_values({[:descMetadata, :source] => val})
    end
    def use_statement
      defaultObjectRights.use_statement.first
    end
    def use_statement=(val)
      defaultObjectRights.update_values({[:use_statement] => val})
    end
    def copyright_statement
      defaultObjectRights.copyright.first
    end
    def copyright_statement=(val)
      defaultObjectRights.update_values({[:copyright] => val})
    end
    def creative_commons_license
      defaultObjectRights.creative_commons.first
    end
    def creative_commons_license_human
      defaultObjectRights.creative_commons_human.first
    end
    def creative_commons_license=(val)
      (machine, human)=val
      if creative_commons_license.nil?
        defaultObjectRights.add_child_node(defaultObjectRights.ng_xml.root, :creative_commons)
      end
      defaultObjectRights.update_values({[:creative_commons] => val})
    end
    def creative_commons_license_human=(val)
      if creative_commons_license_human.nil?
        #add the nodes
       defaultObjectRights.add_child_node(defaultObjectRights.ng_xml.root, :creative_commons)
      end
      defaultObjectRights.update_values({[:creative_commons_human] => val})

    end
    #@return [String] A description of the rights defined in the default object rights datastream. Can be 'Stanford', 'World', 'Dark' or 'None'
    def default_rights
      xml=defaultObjectRights.ng_xml
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
    #Set the rights in default object rights
    #@param rights [String] Stanford, World, Dark, or None
    def default_rights=(rights)
      rights=rights.downcase
      ds = defaultObjectRights
      rights_xml=ds.ng_xml
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
        if rights=='none' || rights == 'dark'
          none_node=Nokogiri::XML::Node.new('none',rights_xml)
          node.add_child(machine_node)
          machine_node.add_child(none_node)
        end
      end
    end

    def desc_metadata_format
      administrativeMetadata.metadata_format.first
    end
    def desc_metadata_format=(format)
      #create the node if it isnt there already
      unless administrativeMetadata.metadata_format.first
        administrativeMetadata.add_child_node(administrativeMetadata.ng_xml.root, :metadata_format)
      end
      administrativeMetadata.update_values({[:metadata_format] => format})
    end
    def desc_metadata_source
      administrativeMetadata.metadata_source.first
    end
    def desc_metadata_source=(source)
      #create the node if it isnt there already
      unless administrativeMetadata.metadata_source.first
        administrativeMetadata.add_child_node(administrativeMetadata.ng_xml.root, :metadata_source)
      end
      administrativeMetadata.update_values({[:metadata_source] => format})
    end
    #List of default workflows, used to provide choices at registration
    #@return [Array] and array of pids, ex ['druid:ab123cd4567']
    def default_workflows
      xml=administrativeMetadata.ng_xml
      nodes=administrativeMetadata.term_values(:registration, :workflow_id)
      if nodes.length > 0
        wfs=[]
        nodes.each do |node|
          wfs << node
        end
        wfs
      else
        []
      end
    end
    #set a single default workflow
    #@param wf [String] the name of the workflow, ex. 'digitizationWF'
    def default_workflow=(wf)
      ds=administrativeMetadata
      xml=ds.ng_xml
      nodes=xml.search('//registration/workflow')
      if nodes.first
        nodes.first['id']=wf
      else
        nodes=xml.search('//registration')
        unless nodes.first
          reg_node=Nokogiri::XML::Node.new('registration',xml)
          xml.root.add_child(reg_node)
        end
        nodes=xml.search('//registration')
        wf_node=Nokogiri::XML::Node.new('workflow',xml)
        wf_node['id']=wf
        nodes.first.add_child(wf_node)
      end
    end
    def agreement
      if agreement_object
        agreement_object.pid
      else
        ''
      end
    end
    def agreement=(val)
      self.agreement_object = Dor::Item.find val.to_s, :cast => true
    end
  end

end
