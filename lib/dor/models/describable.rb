module Dor
  module Describable
    extend ActiveSupport::Concern

    MODS_TO_DC_XSLT = Nokogiri::XSLT(File.new(File.expand_path(File.dirname(__FILE__) + "/mods2dc.xslt")))

    class CrosswalkError < Exception; end

    included do
      has_metadata :name => 'descMetadata', :type => Dor::DescMetadataDS, :label => 'Descriptive Metadata', :control_group => 'M'
    end

    require 'stanford-mods'

    # intended for read-access, "as SearchWorks would see it", mostly for to_solr()
    # @param [Nokogiri::XML::Document] content Nokogiri descMetadata document (overriding internal data)
    # @param [boolean] ns_aware namespace awareness toggle for from_nk_node()
    def stanford_mods(content = nil, ns_aware = true)
      m = Stanford::Mods::Record.new
      desc = content.nil? ? descMetadata.ng_xml : content
      m.from_nk_node(desc.root, ns_aware)
      m
    end

    def fetch_descMetadata_datastream
      candidates = datastreams['identityMetadata'].otherId.collect { |oid| oid.to_s }
      metadata_id = Dor::MetadataService.resolvable(candidates).first
      metadata_id.nil? ? nil : Dor::MetadataService.fetch(metadata_id.to_s)
    end

    def build_descMetadata_datastream(ds)
      content = fetch_descMetadata_datastream
      return nil if content.nil?
      ds.dsLabel = 'Descriptive Metadata'
      ds.ng_xml = Nokogiri::XML(content)
      ds.ng_xml.normalize_text!
      ds.content = ds.ng_xml.to_xml
    end

    # Generates Dublin Core from the MODS in the descMetadata datastream using the LoC mods2dc stylesheet
    #    Should not be used for the Fedora DC datastream
    # @raise [CrosswalkError] Raises an Exception if the generated DC is empty or has no children
    # @return [Nokogiri::Doc] the DublinCore XML document object
    def generate_dublin_core(include_collection_as_related_item: true)
      desc_md = descMetadata.ng_xml.dup(1)
      add_collection_reference(desc_md) if include_collection_as_related_item
      dc_doc = MODS_TO_DC_XSLT.transform(desc_md)
      dc_doc.xpath('/oai_dc:dc/*[count(text()) = 0]').remove # Remove empty nodes
      raise CrosswalkError, "Dor::Item#generate_dublin_core produced incorrect xml (no root):\n#{dc_doc.to_xml}" if dc_doc.root.nil?
      raise CrosswalkError, "Dor::Item#generate_dublin_core produced incorrect xml (no children):\n#{dc_doc.to_xml}" if dc_doc.root.children.size == 0
      dc_doc
    end

    # @return [String] Public descriptive medatada XML
    def generate_public_desc_md
      doc = descMetadata.ng_xml.dup(1)
      add_collection_reference(doc)
      add_access_conditions(doc)
      add_constituent_relations(doc)
      doc.xpath('//comment()').remove
      new_doc = Nokogiri::XML(doc.to_xml) { |x| x.noblanks }
      new_doc.encoding = 'UTF-8'
      new_doc.to_xml
    end

    # Create MODS accessCondition statements from rightsMetadata
    # @param [Nokogiri::XML::Document] doc Document representing the descriptiveMetadata of the object
    # @note this method modifies the passed in doc
    def add_access_conditions(doc)
      # clear out any existing accessConditions
      doc.xpath('//mods:accessCondition', 'mods' => 'http://www.loc.gov/mods/v3').each {|n| n.remove}
      rights = datastreams['rightsMetadata'].ng_xml

      rights.xpath('//use/human[@type="useAndReproduction"]').each do |use|
        txt = use.text.strip
        next if txt.empty?
        doc.root.element_children.last.add_next_sibling doc.create_element('accessCondition', txt, :type => 'useAndReproduction')
      end
      rights.xpath('//copyright/human[@type="copyright"]').each do |cr|
        txt = cr.text.strip
        next if txt.empty?
        doc.root.element_children.last.add_next_sibling doc.create_element('accessCondition', txt, :type => 'copyright')
      end
      rights.xpath("//use/machine[#{ci_compare('type', 'creativecommons')}]").each do |lic_type|
        next if lic_type.text =~ /none/i
        lic_text = rights.at_xpath("//use/human[#{ci_compare('type', 'creativecommons')}]").text.strip
        next if lic_text.empty?
        new_text = "CC #{lic_type.text}: #{lic_text}"
        doc.root.element_children.last.add_next_sibling doc.create_element('accessCondition', new_text, :type => 'license')
      end
      rights.xpath("//use/machine[#{ci_compare('type', 'opendatacommons')}]").each do |lic_type|
        next if lic_type.text =~ /none/i
        lic_text = rights.at_xpath("//use/human[#{ci_compare('type', 'opendatacommons')}]").text.strip
        next if lic_text.empty?
        new_text = "ODC #{lic_type.text}: #{lic_text}"
        doc.root.element_children.last.add_next_sibling doc.create_element('accessCondition', new_text, :type => 'license')
      end
    end

    # Remove existing relatedItem entries for collections from descMetadata
    def remove_related_item_nodes_for_collections(doc)
      doc.search('/mods:mods/mods:relatedItem[@type="host"]/mods:typeOfResource[@collection=\'yes\']', 'mods' => 'http://www.loc.gov/mods/v3').each do |node|
        node.parent.remove
      end
    end

    def add_related_item_node_for_collection(doc, collection_druid)
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

    # Adds to desc metadata a relatedItem with information about the collection this object belongs to.
    # For use in published mods and mods-to-DC conversion.
    # @param [Nokogiri::XML::Document] doc A copy of the descriptiveMetadata of the object, to be modified
    # @return [Void]
    # @note this method modifies the passed in doc
    def add_collection_reference(doc)
      return unless methods.include? :public_relationships
      collections = public_relationships.search('//rdf:RDF/rdf:Description/fedora:isMemberOfCollection',
                                       'fedora' => 'info:fedora/fedora-system:def/relations-external#',
                                       'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#')
      return if collections.empty?

      remove_related_item_nodes_for_collections(doc)

      collections.each do |collection_node|
        collection_druid = collection_node['rdf:resource'].gsub('info:fedora/', '')
        add_related_item_node_for_collection(doc, collection_druid)
      end
    end

    # expand constituent relations into relatedItem references -- see JUMBO-18
    # @param [Nokogiri::XML] doc public MODS XML being built
    # @return [Void]
    def add_constituent_relations(doc)
      public_relationships.search('//rdf:RDF/rdf:Description/fedora:isConstituentOf',
                                       'fedora' => 'info:fedora/fedora-system:def/relations-external#',
                                       'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' ).each do |parent|
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
        title.content = parent_item.datastreams['DC'].title.first
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

    def to_solr(solr_doc = {}, *args)
      solr_doc = super solr_doc, *args
      mods_sources = {
        'sw_language_ssim'            => :sw_language_facet,
        'sw_language_tesim'           => :sw_language_facet,
        'sw_genre_ssim'               => :sw_genre,
        'sw_genre_tesim'              => :sw_genre,
        'sw_format_ssim'              => :format_main,   # basically sw_typeOfResource_ssim
        'sw_format_tesim'             => :format_main,   # basically sw_typeOfResource_tesim
        'sw_subject_temporal_ssim'    => :era_facet,
        'sw_subject_temporal_tesim'   => :era_facet,
        'sw_subject_geographic_ssim'  => :geographic_facet,
        'sw_subject_geographic_tesim' => :geographic_facet,
        'mods_typeOfResource_ssim'    => [:term_values, :typeOfResource],
        'mods_typeOfResource_tesim'   => [:term_values, :typeOfResource]
      }
      keys = mods_sources.keys.concat(%w( metadata_format_ssim ))
      keys.each { |key|
        solr_doc[key] ||= []     # initialize multivalue targts if necessary
      }

      solr_doc['metadata_format_ssim'] << 'mods'
      begin
        dc_doc = generate_dublin_core(include_collection_as_related_item: false)
        # we excluding the generated collection relation here; we instead get the collection
        # title from Dor::Identifiable.
        dc_doc.xpath('/oai_dc:dc/*').each do |node|
          add_solr_value(solr_doc, "public_dc_#{node.name}", node.text, :string, [:stored_searchable])
        end
        creator = ''
        dc_doc.xpath('//dc:creator').each do |node|
          creator = node.text
        end
        title = ''
        dc_doc.xpath('//dc:title').each do |node|
          title = node.text
        end
        creator_title = creator + title
        add_solr_value(solr_doc, 'creator_title', creator_title, :string, [:stored_sortable])
      rescue CrosswalkError => e
        Dor.logger.warn "Cannot index #{pid}.descMetadata: #{e.message}"
      end

      begin
        mods = stanford_mods
        mods_sources.each_pair do |solr_key, meth|
          vals = meth.is_a?(Array) ? mods.send(meth.shift, *meth) : mods.send(meth)
          solr_doc[solr_key].push *vals unless vals.nil? || vals.empty?
          # asterisk to avoid multi-dimensional array: push values, not the array
        end
        solr_doc['sw_pub_date_sort_ssi' ] = mods.pub_year_sort_str  # e.g. '0800'
        solr_doc['sw_pub_date_sort_isi' ] = mods.pub_year_int  # e.g. '0800'
        solr_doc['sw_pub_date_facet_ssi'] = mods.pub_year_display_str # e.g. '9th century'
      end
      # some fields get explicit "(none)" placeholder values, mostly for faceting
      %w(sw_language_tesim sw_genre_tesim sw_format_tesim).each { |key| solr_doc[key] = ['(none)'] if solr_doc[key].empty? }
      # otherwise remove empties
      keys.each { |key| solr_doc.delete(key) if solr_doc[key].nil? || solr_doc[key].empty?}
      solr_doc
    end

    # @param [Boolean] force Overwrite existing XML
    # @return [String] descMetadata.content XML
    def set_desc_metadata_using_label(force = false)
      unless force || descMetadata.new?
        raise 'Cannot proceed, there is already content in the descriptive metadata datastream: ' + descMetadata.content.to_s
      end
      label = self.label
      builder = Nokogiri::XML::Builder.new { |xml|
        xml.mods(
          'xmlns' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', :version => '3.3',
          'xsi:schemaLocation' => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd') {
          xml.titleInfo {
            xml.title label
          }
        }
      }
      descMetadata.content = builder.to_xml
    end

    def self.get_collection_title(obj)
      xml = obj.descMetadata.ng_xml
      title = ''
      title_node = xml.at_xpath('//mods:mods/mods:titleInfo/mods:title', 'mods' => 'http://www.loc.gov/mods/v3')
      if title_node
        title = title_node.content
        subtitle = xml.at_xpath('//mods:mods/mods:titleInfo/mods:subTitle', 'mods' => 'http://www.loc.gov/mods/v3')
        title += " (#{subtitle.content})" if subtitle
      end
      title
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
