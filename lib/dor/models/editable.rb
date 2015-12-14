module Dor
  ## This is basically used just by APOs.  Arguably "editable" is the wrong name.
  module Editable
    extend ActiveSupport::Concern

    included do
      belongs_to :agreement_object, :property => :referencesAgreement, :class_name => 'Dor::Item'
    end

    # these hashes map short ("machine") license codes to their corresponding URIs and human readable titles. they
    # also allow for deprecated entries (via optional :deprecation_warning).  clients that use these maps are advised to
    # only display undeprecated entries, except where a deprecated entry is already in use by an object.  e.g., an APO
    # that already specifies "by_sa" for its default license code could continue displaying that in a list of license options
    # for editing, preferably with the deprecation warning.  but other deprecated entries would be omitted in such a
    # selectbox.
    # TODO: seems like Editable is not the most semantically appropriate place for these mappings?  though they're used
    # by methods that live in Editable.
    # TODO: need some way to do versioning.  for instance, what happens when a new version of an existing license comes
    # out, since it will presumably use the same license code, but a different title and URI?
    CREATIVE_COMMONS_USE_LICENSES = {
      'by' =>       { :human_readable => 'Attribution 3.0 Unported',
                      :uri => 'https://creativecommons.org/licenses/by/3.0/' },
      'by-sa' =>    { :human_readable => 'Attribution Share Alike 3.0 Unported',
                      :uri => 'https://creativecommons.org/licenses/by-sa/3.0/' },
      'by_sa' =>    { :human_readable => 'Attribution Share Alike 3.0 Unported',
                      :uri => 'https://creativecommons.org/licenses/by-sa/3.0/',
                      :deprecation_warning => 'license code "by_sa" was a typo in argo, prefer "by-sa"' },
      'by-nd' =>    { :human_readable => 'Attribution No Derivatives 3.0 Unported',
                      :uri => 'https://creativecommons.org/licenses/by-nd/3.0/' },
      'by-nc' =>    { :human_readable => 'Attribution Non-Commercial 3.0 Unported',
                      :uri => 'https://creativecommons.org/licenses/by-nc/3.0/' },
      'by-nc-sa' => { :human_readable => 'Attribution Non-Commercial Share Alike 3.0 Unported',
                      :uri => 'https://creativecommons.org/licenses/by-nc-sa/3.0/' },
      'by-nc-nd' => { :human_readable => 'Attribution Non-Commercial, No Derivatives 3.0 Unported',
                      :uri => 'https://creativecommons.org/licenses/by-nc-nd/3.0/' },
      'pdm' =>      { :human_readable => 'Public Domain Mark 1.0',
                      :uri => 'https://creativecommons.org/publicdomain/mark/1.0/'}
    }
    OPEN_DATA_COMMONS_USE_LICENSES = {
      'pddl' =>     { :human_readable => 'Open Data Commons Public Domain Dedication and License 1.0',
                      :uri => 'http://opendatacommons.org/licenses/pddl/1.0/' },
      'odc-by' =>   { :human_readable => 'Open Data Commons Attribution License 1.0',
                      :uri => 'http://opendatacommons.org/licenses/by/1.0/' },
      'odc-odbl' => { :human_readable => 'Open Data Commons Open Database License 1.0',
                      :uri => 'http://opendatacommons.org/licenses/odbl/1.0/' }
    }

    def to_solr(solr_doc = {}, *args)
      super(solr_doc, *args)
      add_solr_value(solr_doc, 'default_rights', default_rights, :string, [:symbol])
      add_solr_value(solr_doc, 'agreement', agreement, :string, [:symbol]) if agreement_object
      add_solr_value(solr_doc, 'default_use_license_machine', use_license, :string, [:stored_sortable])
      solr_doc
    end

    # Adds a person or group to a role in the APO role metadata datastream
    #
    # @param role   [String] the role the group or person will be filed under, ex. dor-apo-manager
    # @param entity [String] the name of the person or group, ex dlss:developers or sunetid:someone
    # @param type   [Symbol] :workgroup for a group or :person for a person
    def add_roleplayer(role, entity, type = :workgroup)
      xml = roleMetadata.ng_xml
      group = type == :workgroup ? 'group' : 'person'
      nodes = xml.search('/roleMetadata/role[@type=\'' + role + '\']')
      if nodes.length > 0
        group_node = Nokogiri::XML::Node.new(group, xml)
        id_node = Nokogiri::XML::Node.new('identifier', xml)
        group_node.add_child(id_node)
        id_node.content = entity
        id_node['type'] = type.to_s
        nodes.first.add_child(group_node)
      else
        node = Nokogiri::XML::Node.new('role', xml)
        node['type'] = role
        group_node = Nokogiri::XML::Node.new(group, xml)
        node.add_child group_node
        id_node = Nokogiri::XML::Node.new('identifier', xml)
        group_node.add_child(id_node)
        id_node.content = entity
        id_node['type'] = type.to_s
        xml.search('/roleMetadata').first.add_child(node)
      end
      roleMetadata.content = xml.to_s
    end

    # remove all people groups and roles from the APO role metadata datastream
    def purge_roles
      roleMetadata.ng_xml.search('/roleMetadata/role').each do |node|
        node.remove
      end
    end

    def mods_title
      descMetadata.term_values(:title_info, :main_title).first
    end
    def mods_title=(val)
      descMetadata.update_values({[:title_info, :main_title] => val})
    end

    # get all collections listed for this APO, used during registration
    # @return [Array] array of pids
    def default_collections
      administrativeMetadata.term_values(:registration, :default_collection)
    end
    # Add a collection to the listing of collections for items governed by this apo.
    # @param val [String] pid of the collection, ex. druid:ab123cd4567
    def add_default_collection(val)
      xml = administrativeMetadata.ng_xml
      reg = xml.search('//administrativeMetadata/registration').first
      unless reg
        reg = Nokogiri::XML::Node.new('registration', xml)
        xml.search('/administrativeMetadata').first.add_child(reg)
      end
      node = Nokogiri::XML::Node.new('collection', xml)
      node['id'] = val
      reg.add_child(node)
      administrativeMetadata.content = xml.to_s
    end
    def remove_default_collection(val)
      xml = administrativeMetadata.ng_xml
      xml.search('//administrativeMetadata/registration/collection[@id=\'' + val + '\']').remove
      administrativeMetadata.content = xml.to_s
    end

    # Get all roles defined in the role metadata, and the people or groups in those roles. Groups are prefixed with 'workgroup:'
    # @return [Hash] role => ['person','group'] ex. {"dor-apo-manager" => ["workgroup:dlss:developers", "sunetid:lmcrae"]
    def roles
      roles = {}
      roleMetadata.ng_xml.search('/roleMetadata/role').each do |role|
        roles[role['type']] = []
        role.search('identifier').each do |entity|
          roles[role['type']] << entity['type'] + ':' + entity.text
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
      defaultObjectRights.update_term!(:use_statement, val.nil? ? '' : val)
    end

    def copyright_statement
      defaultObjectRights.copyright.first
    end
    def copyright_statement=(val)
      defaultObjectRights.update_term!(:copyright, val.nil? ? '' : val)
    end

    def creative_commons_license
      defaultObjectRights.creative_commons.first
    end
    def creative_commons_license_human
      defaultObjectRights.creative_commons_human.first
    end

    def open_data_commons_license
      defaultObjectRights.open_data_commons.first
    end
    def open_data_commons_license_human
      defaultObjectRights.open_data_commons_human.first
    end

    def use_license
      return creative_commons_license unless ['', nil].include?(creative_commons_license)
      return open_data_commons_license unless ['', nil].include?(open_data_commons_license)
      ''
    end
    def use_license_uri
      return defaultObjectRights.creative_commons.uri.first unless ['', nil].include?(defaultObjectRights.creative_commons.uri)
      return defaultObjectRights.open_data_commons.uri.first unless ['', nil].include?(defaultObjectRights.open_data_commons.uri)
      ''
    end
    def use_license_human
      return creative_commons_license_human unless ['', nil].include?(creative_commons_license_human)
      return open_data_commons_license_human unless ['', nil].include?(open_data_commons_license_human)
      ''
    end

    def creative_commons_license=(use_license_machine)
      defaultObjectRights.initialize_term!(:creative_commons)
      defaultObjectRights.creative_commons = use_license_machine
      defaultObjectRights.creative_commons.uri = CREATIVE_COMMONS_USE_LICENSES[use_license_machine][:uri]
    end
    def creative_commons_license_human=(use_license_human)
      defaultObjectRights.initialize_term!(:creative_commons_human)
      defaultObjectRights.creative_commons_human = use_license_human
    end

    def open_data_commons_license=(use_license_machine)
      defaultObjectRights.initialize_term!(:open_data_commons)
      defaultObjectRights.open_data_commons = use_license_machine
      defaultObjectRights.open_data_commons.uri = OPEN_DATA_COMMONS_USE_LICENSES[use_license_machine][:uri]
    end
    def open_data_commons_license_human=(use_license_human)
      defaultObjectRights.initialize_term!(:open_data_commons_human)
      defaultObjectRights.open_data_commons_human = use_license_human
    end

    # @param [String|Symbol] use_license_machine The machine code for the desired Use License
    # If set to `:none` then Use License is removed
    def use_license=(use_license_machine)
      if use_license_machine.blank? || use_license_machine == :none
        # delete use license by directly removing the XML used to define the use license
        defaultObjectRights.update_term!(:creative_commons, ' ')
        defaultObjectRights.update_term!(:creative_commons_human, ' ')
        defaultObjectRights.update_term!(:open_data_commons, ' ')
        defaultObjectRights.update_term!(:open_data_commons_human, ' ')
      elsif CREATIVE_COMMONS_USE_LICENSES.include? use_license_machine
        self.creative_commons_license = use_license_machine
        self.creative_commons_license_human = CREATIVE_COMMONS_USE_LICENSES[use_license_machine][:human_readable]
      elsif OPEN_DATA_COMMONS_USE_LICENSES.include? use_license_machine
        self.open_data_commons_license = use_license_machine
        self.open_data_commons_license_human = OPEN_DATA_COMMONS_USE_LICENSES[use_license_machine][:human_readable]
      else
        fail ArgumentError, "'#{use_license_machine}' is not a valid license code"
      end
    end

    # @return [String] A description of the rights defined in the default object rights datastream. Can be 'Stanford', 'World', 'Dark' or 'None'
    def default_rights
      xml = defaultObjectRights.ng_xml
      if xml.search('//rightsMetadata/access[@type=\'read\']/machine/group').length == 1
        'Stanford'
      elsif xml.search('//rightsMetadata/access[@type=\'read\']/machine/world').length == 1
        'World'
      elsif xml.search('//rightsMetadata/access[@type=\'discover\']/machine/none').length == 1
        'Dark'
      else
        'None'
      end
    end
    # Set the rights in default object rights
    # @param rights [String] Stanford, World, Dark, or None
    def default_rights=(rights)
      rights = rights.downcase
      rights_xml = defaultObjectRights.ng_xml
      rights_xml.search('//rightsMetadata/access[@type=\'discover\']/machine').each do |node|
        node.children.remove
        world_node = Nokogiri::XML::Node.new((rights == 'dark' ? 'none' : 'world'), rights_xml)
        node.add_child(world_node)
      end
      rights_xml.search('//rightsMetadata/access[@type=\'read\']').each do |node|
        node.children.remove
        machine_node = Nokogiri::XML::Node.new('machine', rights_xml)
        if rights == 'world'
          world_node = Nokogiri::XML::Node.new(rights, rights_xml)
          node.add_child(machine_node)
          machine_node.add_child(world_node)
        elsif rights == 'stanford'
          node.add_child(machine_node)
          group_node = Nokogiri::XML::Node.new('group', rights_xml)
          group_node.content = 'Stanford'
          node.add_child(machine_node)
          machine_node.add_child(group_node)
        elsif rights == 'none' || rights == 'dark'
          none_node = Nokogiri::XML::Node.new('none', rights_xml)
          node.add_child(machine_node)
          machine_node.add_child(none_node)
        else
          raise ArgumentError, "Unrecognized rights value '#{rights}'"
        end
      end
    end

    def desc_metadata_format
      administrativeMetadata.metadata_format.first
    end
    def desc_metadata_format=(format)
      # create the node if it isnt there already
      unless administrativeMetadata.metadata_format.first
        administrativeMetadata.add_child_node(administrativeMetadata.ng_xml.root, :metadata_format)
      end
      administrativeMetadata.update_values({[:metadata_format] => format})
    end

    def desc_metadata_source
      administrativeMetadata.metadata_source.first
    end
    def desc_metadata_source=(source)
      # create the node if it isnt there already
      unless administrativeMetadata.metadata_source.first
        administrativeMetadata.add_child_node(administrativeMetadata.ng_xml.root, :metadata_source)
      end
      administrativeMetadata.update_values({[:metadata_source] => format})
    end

    # List of default workflows, used to provide choices at registration
    # @return [Array] and array of pids, ex ['druid:ab123cd4567']
    def default_workflows
      administrativeMetadata.term_values(:registration, :workflow_id)
    end
    # set a single default workflow
    # @param wf [String] the name of the workflow, ex. 'digitizationWF'
    def default_workflow=(wf)
      fail ArgumentError, 'Must have a valid workflow for default' if wf.blank?
      xml = administrativeMetadata.ng_xml
      nodes = xml.search('//registration/workflow')
      if nodes.first
        nodes.first['id'] = wf
      else
        nodes = xml.search('//registration')
        unless nodes.first
          reg_node = Nokogiri::XML::Node.new('registration', xml)
          xml.root.add_child(reg_node)
        end
        nodes = xml.search('//registration')
        wf_node = Nokogiri::XML::Node.new('workflow', xml)
        wf_node['id'] = wf
        nodes.first.add_child(wf_node)
      end
    end

    def agreement
      agreement_object ? agreement_object.pid : ''
    end
    def agreement=(val)
      fail ArgumentError, 'agreement must have a valid druid' if val.blank?
      self.agreement_object = Dor::Item.find val.to_s, :cast => true
    end
  end
end
