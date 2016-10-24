module Dor
  class RightsMetadataDS < ActiveFedora::OmDatastream
    require 'dor/rights_auth'

    attr_writer :dra_object

    # This is separate from default_object_rights because
    # (1) we cannot default to such a permissive state
    # (2) this is real, not default
    #
    # Ultimately, default_object_rights should go away and APOs also use an instantation of this class

    set_terminology do |t|
      t.root :path => 'rightsMetadata', :index_as => [:not_searchable]
      t.copyright :path => 'copyright/human', :index_as => [:symbol]
      t.use_statement :path => '/use/human[@type=\'useAndReproduction\']', :index_as => [:symbol]

      t.use do
        t.machine
        t.human
      end

      t.creative_commons :path => '/use/machine[@type=\'creativeCommons\']', :type => 'creativeCommons' do
        t.uri :path => '@uri'
      end
      t.creative_commons_human :path => '/use/human[@type=\'creativeCommons\']'
      t.open_data_commons :path => '/use/machine[@type=\'openDataCommons\']', :type => 'openDataCommons' do
        t.uri :path => '@uri'
      end
      t.open_data_commons_human :path => '/use/human[@type=\'openDataCommons\']'
    end

    def self.xml_template
      Nokogiri::XML::Builder.new do |xml|
        xml.rightsMetadata {
          xml.access(:type => 'discover') {
            xml.machine { xml.none }
          }
          xml.access(:type => 'read') {
            xml.machine { xml.none }   # dark default
          }
          xml.use {
            xml.human(:type => 'useAndReproduction')
            xml.human(:type => 'creativeCommons')
            xml.machine(:type => 'creativeCommons', :uri => '')
            xml.human(:type => 'openDataCommons')
            xml.machine(:type => 'openDataCommons', :uri => '')
          }
          xml.copyright { xml.human }
        }
      end.doc
    end

    # just a wrapper to invalidate @dra_object
    def content=(xml)
      @dra_object = nil
      super
    end

    def dra_object
      @dra_object ||= Dor::RightsAuth.parse(ng_xml, true)
    end

    # @param rights [string] archetypical rights to assign: 'world', 'stanford', 'none' or 'dark'
    # Moved from Governable
    # slight misnomer: also sets discover rights!
    # TODO: convert xpath reads to dra_object calls
    def set_read_rights(rights)
      raise(ArgumentError, "Argument '#{rights}' is not a recognized value") unless %w(world stanford none dark).include? rights
      rights_xml = ng_xml
      if rights_xml.search('//rightsMetadata/access[@type=\'read\']').length == 0
        raise('The rights metadata stream doesnt contain an entry for machine read permissions. Consider populating it from the APO before trying to change it.')
      end
      label = rights == 'dark' ? 'none' : 'world'
      @dra_object = nil # until TODO complete, we'll expect to have to reparse after modification
      rights_xml.search('//rightsMetadata/access[@type=\'discover\']/machine').each do |node|
        node.children.remove
        node.add_child Nokogiri::XML::Node.new(label, rights_xml)
      end
      rights_xml.search('//rightsMetadata/access[@type=\'read\']').each do |node|
        node.children.remove
        machine_node = Nokogiri::XML::Node.new('machine', rights_xml)
        node.add_child(machine_node)
        if rights == 'world'
          machine_node.add_child Nokogiri::XML::Node.new(rights, rights_xml)
        elsif rights == 'stanford'
          group_node = Nokogiri::XML::Node.new('group', rights_xml)
          group_node.content = 'Stanford'
          machine_node.add_child(group_node)
        else  # we know it is none or dark by the argument filter (first line)
          machine_node.add_child Nokogiri::XML::Node.new('none', rights_xml)
        end
      end
      self.content = rights_xml.to_xml
      content_will_change!
    end

    def to_solr(solr_doc = {}, *args)
      solr_doc = super(solr_doc, *args)
      dra = dra_object
      solr_doc['rights_primary_ssi'] = dra.index_elements[:primary]
      solr_doc['rights_errors_ssim'] = dra.index_elements[:errors] if dra.index_elements[:errors].size > 0
      solr_doc['rights_characteristics_ssim'] = dra.index_elements[:terms] if dra.index_elements[:terms].size > 0

      solr_doc['rights_descriptions_ssim'] = [
        dra.index_elements[:primary],

        (dra.index_elements[:obj_locations_qualified] || []).map do |rights_info|
          rule_suffix = rights_info[:rule] ? " (#{rights_info[:rule]})" : ''
          "location: #{rights_info[:location]}#{rule_suffix}"
        end,
        (dra.index_elements[:file_locations_qualified] || []).map do |rights_info|
          rule_suffix = rights_info[:rule] ? " (#{rights_info[:rule]})" : ''
          "location: #{rights_info[:location]} (file)#{rule_suffix}"
        end,

        (dra.index_elements[:obj_agents_qualified] || []).map do |rights_info|
          rule_suffix = rights_info[:rule] ? " (#{rights_info[:rule]})" : ''
          "agent: #{rights_info[:agent]}#{rule_suffix}"
        end,
        (dra.index_elements[:file_agents_qualified] || []).map do |rights_info|
          rule_suffix = rights_info[:rule] ? " (#{rights_info[:rule]})" : ''
          "agent: #{rights_info[:agent]} (file)#{rule_suffix}"
        end,

        (dra.index_elements[:obj_groups_qualified] || []).map do |rights_info|
          rule_suffix = rights_info[:rule] ? " (#{rights_info[:rule]})" : ''
          "#{rights_info[:group]}#{rule_suffix}"
        end,
        (dra.index_elements[:file_groups_qualified] || []).map do |rights_info|
          rule_suffix = rights_info[:rule] ? " (#{rights_info[:rule]})" : ''
          "#{rights_info[:group]} (file)#{rule_suffix}"
        end,

        (dra.index_elements[:obj_world_qualified] || []).map do |rights_info|
          rule_suffix = rights_info[:rule] ? " (#{rights_info[:rule]})" : ''
          "world#{rule_suffix}"
        end,
        (dra.index_elements[:file_world_qualified] || []).map do |rights_info|
          rule_suffix = rights_info[:rule] ? " (#{rights_info[:rule]})" : ''
          "world (file)#{rule_suffix}"
        end
      ].flatten.uniq

      # these two values are returned by index_elements[:primary], but are just a less granular version of
      # what the other more specific fields return, so discard them
      solr_doc['rights_descriptions_ssim'].reject! { |rights_desc| ['access_restricted', 'access_restricted_qualified', 'world_qualified'].include? rights_desc }
      solr_doc['rights_descriptions_ssim'] << 'dark (file)' if dra.index_elements[:terms].include? 'none_read_file'

      solr_doc['obj_rights_locations_ssim'] = dra.index_elements[:obj_locations] if !dra.index_elements[:obj_locations].blank?
      solr_doc['file_rights_locations_ssim'] = dra.index_elements[:file_locations] if !dra.index_elements[:file_locations].blank?
      solr_doc['obj_rights_agents_ssim'] = dra.index_elements[:obj_agents] if !dra.index_elements[:obj_agents].blank?
      solr_doc['file_rights_agents_ssim'] = dra.index_elements[:file_agents] if !dra.index_elements[:file_agents].blank?

      # suppress empties
      %w(use_statement_ssim copyright_ssim).each do |key|
        solr_doc[key] = solr_doc[key].reject { |val| val.nil? || val == '' }.flatten unless solr_doc[key].nil?
      end
      add_solr_value(solr_doc, 'use_license_machine', use_license, :string, [:stored_sortable])

      solr_doc
    end

    def use_license
      return creative_commons unless ['', nil].include?(creative_commons)
      return open_data_commons unless ['', nil].include?(open_data_commons)
      ''
    end

    # maintain AF < 8 indexing behavior
    def prefix
      ''
    end

  end # class
end
