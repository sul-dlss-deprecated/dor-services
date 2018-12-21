# frozen_string_literal: true

module Dor
  class RoleMetadataDS < ActiveFedora::OmDatastream
    include SolrDocHelper

    set_terminology do |t|
      t.root path: 'roleMetadata'

      t.actor do
        t.identifier do
          t.type_ path: { attribute: 'type' }
        end
        t.name
      end
      t.person ref: [:actor], path: 'person'
      t.group  ref: [:actor], path: 'group'

      t.role do
        t.type_ path: { attribute: 'type' }
        t.person ref: [:person]
        t.group  ref: [:group]
      end

      t.manager    ref: [:role], attributes: { type: 'manager' }
      t.depositor  ref: [:role], attributes: { type: 'depositor' }
      t.reviewer   ref: [:role], attributes: { type: 'reviewer' }
      t.viewer     ref: [:role], attributes: { type: 'viewer' }
    end

    def self.xml_template
      Nokogiri::XML::Builder.new do |xml|
        xml.roleMetadata {}
      end.doc
    end

    def to_solr(solr_doc = {}, *_args)
      find_by_xpath('/roleMetadata/role/*').each do |actor|
        role_type = actor.parent['type']
        val = [actor.at_xpath('identifier/@type'), actor.at_xpath('identifier/text()')].join ':'
        add_solr_value(solr_doc, "apo_role_#{actor.name}_#{role_type}", val, :string, [:symbol])
        add_solr_value(solr_doc, "apo_role_#{role_type}", val, :string, [:symbol])
        add_solr_value(solr_doc, 'apo_register_permissions', val, :string, %i[symbol stored_searchable]) if ['dor-apo-manager', 'dor-apo-depositor'].include? role_type
      end
      solr_doc
    end

    # Adds a person or group to a role in the APO role metadata datastream
    #
    # @param role   [String] the role the group or person will be filed under, ex. dor-apo-manager
    # @param entity [String] the name of the person or group, ex dlss:developers or sunetid:someone
    # @param type   [Symbol] :workgroup for a group or :person for a person
    def add_roleplayer(role, entity, type = :workgroup)
      xml = ng_xml
      ng_xml_will_change!
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
    end

    # remove all people groups and roles from the APO role metadata datastream
    def purge_roles
      ng_xml.search('/roleMetadata/role').each(&:remove)
    end

    # Get all roles defined in the role metadata, and the people or groups in those roles. Groups are prefixed with 'workgroup:'
    # @return [Hash] role => ['person','group'] ex. {"dor-apo-manager" => ["workgroup:dlss:developers", "sunetid:lmcrae"]
    def roles
      {}.tap do |roles|
        ng_xml.search('/roleMetadata/role').each do |role|
          roles[role['type']] = []
          role.search('identifier').each do |entity|
            roles[role['type']] << entity['type'] + ':' + entity.text
          end
        end
      end
    end

    # maintain AF < 8 indexing behavior
    def prefix
      ''
    end
  end
end
