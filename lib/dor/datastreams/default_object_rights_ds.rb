# frozen_string_literal: true

require 'stanford/mods/normalizer'
module Dor
  class DefaultObjectRightsDS < ActiveFedora::OmDatastream
    # Note that the XSL file was taken from the (apparently defunct) nokogiri-pretty project:
    # https://github.com/tobym/nokogiri-pretty/blob/master/lib/indent.xsl
    # The only modification made was to declare UTF-8 to be the encoding, instead of ISO-8859-1.
    HUMAN_XSLT = Nokogiri::XSLT(File.read(File.expand_path('human.xslt', __dir__)))

    set_terminology do |t|
      t.root path: 'rightsMetadata', index_as: [:not_searchable]
      t.copyright path: 'copyright/human', index_as: [:symbol]
      t.use_statement path: '/use/human[@type=\'useAndReproduction\']', index_as: [:symbol]

      # t.use do
      #   t.machine
      #   t.human
      # end

      t.creative_commons path: '/use/machine[@type=\'creativeCommons\']', type: 'creativeCommons' do
        t.uri path: '@uri'
      end
      t.creative_commons_human path: '/use/human[@type=\'creativeCommons\']'
      t.open_data_commons path: '/use/machine[@type=\'openDataCommons\']', type: 'openDataCommons' do
        t.uri path: '@uri'
      end
      t.open_data_commons_human path: '/use/human[@type=\'openDataCommons\']'
    end

    define_template :creative_commons do |xml|
      xml.use do
        xml.human(type: 'creativeCommons')
        xml.machine(type: 'creativeCommons', uri: '')
      end
    end

    define_template :open_data_commons do |xml|
      xml.use do
        xml.human(type: 'openDataCommons')
        xml.machine(type: 'openDataCommons', uri: '')
      end
    end

    define_template :copyright do |xml|
      xml.copyright do
        xml.human
      end
    end

    define_template :use_statement do |xml|
      xml.use do
        xml.human(type: 'useAndReproduction')
      end
    end

    def self.xml_template
      Nokogiri::XML::Builder.new do |xml|
        xml.rightsMetadata do
          xml.access(type: 'discover') do
            xml.machine do
              xml.world
            end
          end
          xml.access(type: 'read') do
            xml.machine do
              xml.world
            end
          end
          xml.use do
            xml.human(type: 'useAndReproduction')
            xml.human(type: 'creativeCommons')
            xml.machine(type: 'creativeCommons', uri: '')
            xml.human(type: 'openDataCommons')
            xml.machine(type: 'openDataCommons', uri: '')
          end
          xml.copyright do
            xml.human
          end
        end
      end.doc
    end

    # Ensures that the template is present for the given term
    def initialize_term!(term)
      return unless find_by_terms(term).length < 1

      ng_xml_will_change!
      add_child_node(ng_xml.root, term)
    end

    # Assigns the defaultObjectRights object's term with the given value. Supports setting value to nil
    def update_term!(term, val)
      ng_xml_will_change!
      if val.blank?
        update_values([term] => nil)
      else
        initialize_term! term
        update_values([term] => val)
      end
      normalize!
    end

    def content
      prettify(ng_xml).to_s
    end

    # Purge the XML of any empty or duplicate elements -- keeps <rightsMetadata> clean
    def normalize!
      ng_xml_will_change!
      doc = ng_xml
      if doc.xpath('/rightsMetadata/use').length > 1
        # <use> node needs consolidation
        nodeset = doc.xpath('/rightsMetadata/use')
        nodeset[1..-1].each do |node|
          node.children.each do |child|
            nodeset[0] << child # copy over to first <use> element
          end
          node.remove
        end
        raise unless doc.xpath('/rightsMetadata/use').length == 1
      end

      # Call out to the general purpose XML normalization service
      Stanford::Mods::Normalizer.new.tap do |norm|
        norm.remove_empty_attributes(doc.root)
        # cleanup ordering is important here
        doc.xpath('//machine/text()').each { |node| node.content = node.content.strip }
        doc.xpath('//human')
           .tap { |node_set| norm.clean_linefeeds(node_set) }
           .each do |node|
          norm.trim_text(node)
          norm.remove_empty_nodes(node)
        end
        doc.xpath('/rightsMetadata/copyright').each { |node| norm.remove_empty_nodes(node) }
        doc.xpath('/rightsMetadata/use').each { |node| norm.remove_empty_nodes(node) }
      end
      self.content = prettify(doc)
    end

    # Returns a nicely indented XML document.
    def prettify(xml_doc)
      HUMAN_XSLT.apply_to(xml_doc)
    end

    def use_statement
      super.first
    end

    def use_statement=(val)
      update_term!(:use_statement, val.nil? ? '' : val)
    end

    def copyright_statement
      copyright.first
    end

    def copyright_statement=(val)
      update_term!(:copyright, val.nil? ? '' : val)
    end

    def creative_commons_license
      creative_commons.first
    end

    def creative_commons_license_human
      creative_commons_human.first
    end

    def open_data_commons_license
      open_data_commons.first
    end

    def open_data_commons_license_human
      open_data_commons_human.first
    end

    def use_license
      return creative_commons_license unless creative_commons_license.blank?
      return open_data_commons_license unless open_data_commons_license.blank?

      nil
    end

    def use_license_uri
      return creative_commons.uri.first unless creative_commons.uri.blank?
      return open_data_commons.uri.first unless open_data_commons.uri.blank?

      nil
    end

    def use_license_human
      return creative_commons_license_human unless creative_commons_license_human.blank?
      return open_data_commons_license_human unless open_data_commons_license_human.blank?

      nil
    end

    def creative_commons_license=(use_license_machine)
      initialize_term!(:creative_commons)
      self.creative_commons = use_license_machine
      creative_commons.uri = CreativeCommonsLicenseService.property(use_license_machine).uri
    end

    def creative_commons_license_human=(use_license_human)
      initialize_term!(:creative_commons_human)
      self.creative_commons_human = use_license_human
    end

    def open_data_commons_license=(use_license_machine)
      initialize_term!(:open_data_commons)
      self.open_data_commons = use_license_machine
      open_data_commons.uri = OpenDataLicenseService.property(use_license_machine).uri
    end

    def open_data_commons_license_human=(use_license_human)
      initialize_term!(:open_data_commons_human)
      self.open_data_commons_human = use_license_human
    end

    # @param [String|Symbol] use_license_machine The machine code for the desired Use License
    # If set to `:none` then Use License is removed
    def use_license=(use_license_machine)
      if use_license_machine.blank? || use_license_machine == :none
        # delete use license by directly removing the XML used to define the use license
        update_term!(:creative_commons, ' ')
        update_term!(:creative_commons_human, ' ')
        update_term!(:open_data_commons, ' ')
        update_term!(:open_data_commons_human, ' ')
      elsif CreativeCommonsLicenseService.key? use_license_machine
        self.creative_commons_license = use_license_machine
        self.creative_commons_license_human = CreativeCommonsLicenseService.property(use_license_machine).label
      elsif OpenDataLicenseService.key? use_license_machine
        self.open_data_commons_license = use_license_machine
        self.open_data_commons_license_human = OpenDataLicenseService.property(use_license_machine).label
      else
        raise ArgumentError, "'#{use_license_machine}' is not a valid license code"
      end
    end

    # @return [String] A description of the rights defined in the default object rights datastream. Can be one of
    # RightsMetadataDS::RIGHTS_TYPE_CODES.keys (so this is essentially the inverse of RightsMetadataDS.upd_rights_xml_for_rights_type).
    def default_rights
      xml = ng_xml
      machine_read_access = xml.search('//rightsMetadata/access[@type="read"]/machine')
      machine_discover_access = xml.search('//rightsMetadata/access[@type="discover"]/machine')

      machine_read_access_node = machine_read_access.length == 1 ? machine_read_access.first : nil
      machine_discover_access_node = machine_discover_access.length == 1 ? machine_discover_access.first : nil

      if machine_read_access_node && machine_read_access_node.search('./group[text()="Stanford" or text()="stanford"]').length == 1
        if machine_read_access_node.search('./group[@rule="no-download"]').length == 1
          'stanford-nd'
        else
          'stanford'
        end
      elsif machine_read_access_node && machine_read_access_node.search('./world').length == 1
        if machine_read_access_node.search('./world[@rule="no-download"]').length == 1
          'world-nd'
        else
          'world'
        end
      elsif machine_read_access_node && machine_read_access_node.search('./location[text()="spec"]').length == 1
        'loc:spec'
      elsif machine_read_access_node && machine_read_access_node.search('./location[text()="music"]').length == 1
        'loc:music'
      elsif machine_discover_access_node && machine_discover_access_node.search('./world').length == 1
        # if it's not stanford restricted, world readable, or location restricted, but it is world discoverable, it's "citation only"
        'none'
      elsif machine_discover_access_node && machine_discover_access_node.search('./none').length == 1
        # if it's not even discoverable, it's "dark"
        'dark'
      end
    end

    # Set the rights in default object rights
    # @param rights [String] Stanford, World, Dark, or None
    def default_rights=(rights)
      rights = rights.downcase
      raise(ArgumentError, "Unrecognized rights value '#{rights}'") unless RightsMetadataDS.valid_rights_type? rights

      rights_xml = ng_xml
      ng_xml_will_change!
      RightsMetadataDS.upd_rights_xml_for_rights_type(rights_xml, rights)
    end

    # maintain AF < 8 indexing behavior
    def prefix
      ''
    end
  end
end
