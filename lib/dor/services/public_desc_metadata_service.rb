# frozen_string_literal: true

module Dor
  class PublicDescMetadataService
    attr_reader :object

    NOKOGIRI_DEEP_COPY = 1

    def initialize(object)
      @object = object
    end

    def doc
      @doc ||= object.descMetadata.ng_xml.dup(NOKOGIRI_DEEP_COPY)
    end

    # @return [String] Public descriptive medatada XML
    def to_xml(include_access_conditions: true)
      ng_xml(include_access_conditions: include_access_conditions).to_xml
    end

    # @return [Nokogiri::XML::Document]
    def ng_xml(include_access_conditions: true)
      @ng_xml ||= begin
        add_collection_reference!
        add_access_conditions! if include_access_conditions
        add_constituent_relations!
        strip_comments!

        new_doc = Nokogiri::XML(doc.to_xml, &:noblanks)
        new_doc.encoding = 'UTF-8'
        new_doc
      end
    end

    private

    def strip_comments!
      doc.xpath('//comment()').remove
    end

    # Create MODS accessCondition statements from rightsMetadata
    # @param [Nokogiri::XML::Document] doc Document representing the descriptiveMetadata of the object
    # @note this method modifies the passed in doc
    def add_access_conditions!
      # clear out any existing accessConditions
      doc.xpath('//mods:accessCondition', 'mods' => 'http://www.loc.gov/mods/v3').each(&:remove)
      rights = object.datastreams['rightsMetadata'].ng_xml

      rights.xpath('//use/human[@type="useAndReproduction"]').each do |use|
        txt = use.text.strip
        next if txt.empty?

        doc.root.element_children.last.add_next_sibling doc.create_element('accessCondition', txt, type: 'useAndReproduction')
      end
      rights.xpath('//copyright/human[@type="copyright"]').each do |cr|
        txt = cr.text.strip
        next if txt.empty?

        doc.root.element_children.last.add_next_sibling doc.create_element('accessCondition', txt, type: 'copyright')
      end
      rights.xpath("//use/machine[#{ci_compare('type', 'creativecommons')}]").each do |lic_type|
        next if lic_type.text =~ /none/i

        lic_text = rights.at_xpath("//use/human[#{ci_compare('type', 'creativecommons')}]").text.strip
        next if lic_text.empty?

        new_text = "CC #{lic_type.text}: #{lic_text}"
        doc.root.element_children.last.add_next_sibling doc.create_element('accessCondition', new_text, type: 'license')
      end
      rights.xpath("//use/machine[#{ci_compare('type', 'opendatacommons')}]").each do |lic_type|
        next if lic_type.text =~ /none/i

        lic_text = rights.at_xpath("//use/human[#{ci_compare('type', 'opendatacommons')}]").text.strip
        next if lic_text.empty?

        new_text = "ODC #{lic_type.text}: #{lic_text}"
        doc.root.element_children.last.add_next_sibling doc.create_element('accessCondition', new_text, type: 'license')
      end
    end

    # expand constituent relations into relatedItem references -- see JUMBO-18
    # @param [Nokogiri::XML] doc public MODS XML being built
    # @return [Void]
    def add_constituent_relations!
      object.public_relationships.search('//rdf:RDF/rdf:Description/fedora:isConstituentOf',
                                         'fedora' => 'info:fedora/fedora-system:def/relations-external#',
                                         'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#').each do |parent|
        # fetch the parent object to get title
        druid = parent['rdf:resource'].gsub(/^info:fedora\//, '')
        parent_item = Dor.find(druid)

        # create the MODS relation
        relatedItem = doc.create_element 'relatedItem'
        relatedItem['type'] = 'host'
        relatedItem['displayLabel'] = 'Appears in'

        # load the title from the parent's DC.title
        titleInfo = doc.create_element 'titleInfo'
        title = doc.create_element 'title'
        title.content = Dor::Describable.get_collection_title(parent_item)
        titleInfo << title
        relatedItem << titleInfo

        # point to the PURL for the parent
        location = doc.create_element 'location'
        url = doc.create_element 'url'
        url.content = "http://#{Dor::Config.stacks.document_cache_host}/#{druid.split(':').last}"
        location << url
        relatedItem << location

        # finish up by adding relation to public MODS
        doc.root << relatedItem
      end
    end

    # Adds to desc metadata a relatedItem with information about the collection this object belongs to.
    # For use in published mods and mods-to-DC conversion.
    # @param [Nokogiri::XML::Document] doc A copy of the descriptiveMetadata of the object, to be modified
    # @return [Void]
    # @note this method modifies the passed in doc
    def add_collection_reference!
      collections = object.public_relationships.search('//rdf:RDF/rdf:Description/fedora:isMemberOfCollection',
                                                       'fedora' => 'info:fedora/fedora-system:def/relations-external#',
                                                       'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#')
      return if collections.empty?

      remove_related_item_nodes_for_collections!

      collections.each do |collection_node|
        collection_druid = collection_node['rdf:resource'].gsub('info:fedora/', '')
        add_related_item_node_for_collection! collection_druid
      end
    end

    # Remove existing relatedItem entries for collections from descMetadata
    def remove_related_item_nodes_for_collections!
      doc.search('/mods:mods/mods:relatedItem[@type="host"]/mods:typeOfResource[@collection=\'yes\']', 'mods' => 'http://www.loc.gov/mods/v3').each do |node|
        node.parent.remove
      end
    end

    def add_related_item_node_for_collection!(collection_druid)
      begin
        collection_obj = Dor.find(collection_druid)
      rescue ActiveFedora::ObjectNotFoundError
        return nil
      end

      title_node         = Nokogiri::XML::Node.new('title', doc)
      title_node.content = Dor::Describable.get_collection_title(collection_obj)

      title_info_node = Nokogiri::XML::Node.new('titleInfo', doc)
      title_info_node.add_child(title_node)

      # e.g.:
      #   <location>
      #     <url>http://purl.stanford.edu/rh056sr3313</url>
      #   </location>
      loc_node = doc.create_element('location')
      url_node = doc.create_element('url')
      url_node.content = "https://#{Dor::Config.stacks.document_cache_host}/#{collection_druid.split(':').last}"
      loc_node << url_node

      type_node = Nokogiri::XML::Node.new('typeOfResource', doc)
      type_node['collection'] = 'yes'

      related_item_node = Nokogiri::XML::Node.new('relatedItem', doc)
      related_item_node['type'] = 'host'

      related_item_node.add_child(title_info_node)
      related_item_node.add_child(loc_node)
      related_item_node.add_child(type_node)

      doc.root.add_child(related_item_node)
    end

    private

    # Builds case-insensitive xpath translate function call that will match the attribute to a value
    def ci_compare(attribute, value)
      "translate(
        @#{attribute},
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
        'abcdefghijklmnopqrstuvwxyz'
       ) = '#{value}' "
    end
  end
end
