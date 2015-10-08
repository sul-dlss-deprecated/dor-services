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

      t.creative_commons :path => '/use/machine', :type => 'creativeCommons' do
        t.uri :path => '@uri'
      end
      t.creative_commons_human :path => '/use/human[@type=\'creativeCommons\']'
      t.open_data_commons :path => '/use/machine', :type => 'openDataCommons' do
        t.uri :path => '@uri'
      end
      t.open_data_commons_human :path => '/use/human[@type=\'openDataCommons\']'
    end

    define_template :creative_commons do |xml|
      xml.use {
        xml.human(:type => 'creativeCommons')
        xml.machine(:type => 'creativeCommons', :uri =>'')
      }
    end

    define_template :open_data_commons do |xml|
      xml.use {
        xml.human(:type => 'openDataCommons')
        xml.machine(:type => 'openDataCommons', :uri =>'')
      }
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
            xml.machine(:type => 'creativeCommons', :uri =>'')
            xml.human(:type => 'openDataCommons')
            xml.machine(:type => 'openDataCommons', :uri =>'')
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
      if (rights_xml.search('//rightsMetadata/access[@type=\'read\']').length == 0)
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
      super(solr_doc, *args)
      dra = dra_object
      solr_doc['rights_primary_ssi'] = dra.index_elements[:primary]
      solr_doc['rights_errors_ssim'] = dra.index_elements[:errors] if dra.index_elements[:errors].size > 0
      solr_doc['rights_characteristics_ssim'] = dra.index_elements[:terms] if dra.index_elements[:terms].size > 0
      # suppress empties
      %w[use_statement_ssim copyright_ssim].each do |key|
        solr_doc[key] = solr_doc[key].reject { |val| val.nil? || val == '' }.flatten unless solr_doc[key].nil?
      end
      solr_doc
    end

  end #class
end
