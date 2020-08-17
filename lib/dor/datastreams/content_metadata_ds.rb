# frozen_string_literal: true

require 'set'

module Dor
  class ContentMetadataDS < ActiveFedora::OmDatastream
    set_terminology do |t|
      t.root        path: 'contentMetadata',          index_as: [:not_searchable]
      t.contentType path: { attribute: 'type' },      index_as: [:not_searchable]
      t.stacks      path: '/contentMetadata/@stacks', index_as: [:not_searchable]
      t.resource(index_as: [:not_searchable]) do
        t.id_       path: { attribute: 'id' }
        t.sequence  path: { attribute: 'sequence' } # , :data_type => :integer
        t.type_     path: { attribute: 'type' }, index_as: [:displayable]
        t.attribute(path: 'attr', index_as: [:not_searchable]) do
          t.name    path: { attribute: 'name' }, index_as: [:not_searchable]
        end
        t.file(index_as: [:not_searchable]) do
          t.id_      path: { attribute: 'id' }
          t.mimeType path: { attribute: 'mimeType' }, index_as: [:displayable]
          t.dataType path: { attribute: 'dataType' }, index_as: [:displayable]
          t.size     path: { attribute: 'size'     }, index_as: [:displayable]    # , :data_type => :long
          t.role     path: { attribute: 'role' },     index_as: [:not_searchable]
          t.shelve   path: { attribute: 'shelve'   }, index_as: [:not_searchable] # , :data_type => :boolean
          t.publish  path: { attribute: 'publish'  }, index_as: [:not_searchable] # , :data_type => :boolean
          t.preserve path: { attribute: 'preserve' }, index_as: [:not_searchable] # , :data_type => :boolean
          t.checksum do
            t.type_ path: { attribute: 'type' }
          end
        end
        t.shelved_file(path: 'file', attributes: { shelve: 'yes' }, index_as: [:not_searchable]) do
          t.id_ path: { attribute: 'id' }, index_as: %i[displayable stored_searchable]
        end
      end
      t.shelved_file_id proxy: %i[resource shelved_file id], index_as: %i[displayable stored_searchable]
    end

    def self.xml_template
      Nokogiri::XML.parse('<contentMetadata/>')
    end

    ### READ ONLY METHODS

    # Only use this when you want the behavior of raising an exception if anything besides exactly one matching node
    # is found.  Otherwise just use .xpath, .at_xpath or .search.
    # @param xpath [String] accessor invocation for Nokogiri xpath
    # @return [Nokogiri::XML::Element] the matched element
    def singular_node(xpath)
      node = ng_xml.search(xpath)
      len  = node.length
      raise "#{xpath} not found" if len < 1
      raise "#{xpath} duplicated: #{len} found" if len != 1

      node.first
    end

    # Generates the XML tree for externalFile references. For example:
    #     <externalFile objectId="druid:mn123pq4567" resourceId="Image01" fileId="image_01.jp2000" mimetype="image/jp2" />
    # @param [String] objectId the linked druid
    # @param [String] resourceId the linked druid's resource identifier
    # @param [String] fileId the linked druid's resource's file identifier
    # @param [String] mimetype the file's MIME type
    # @return [Nokogiri::XML::Element]
    def generate_external_file_node(object_id, resource_id, file_id, mimetype)
      externalFile = ng_xml.create_element 'externalFile'
      externalFile[:objectId]   = object_id
      externalFile[:resourceId] = resource_id
      externalFile[:fileId]     = file_id
      externalFile[:mimetype]   = mimetype
      externalFile
    end

    # Generates the XML tree for virtual resource relationship reference. For example:
    #   <relationship type="alsoAvailableAs" objectId="druid:mn123pq4567" />
    # @param [String] objectId the linked druid
    # @return [Nokogiri::XML::Element]
    def generate_also_available_as_node(object_id)
      relationship = ng_xml.create_element 'relationship'
      relationship[:type] = 'alsoAvailableAs'
      relationship[:objectId] = object_id
      relationship
    end

    # Terminology-based solrization is going to be painfully slow for large
    # contentMetadata streams. Just select the relevant elements instead.
    # TODO: Call super()?
    def to_solr(solr_doc = {}, *_args)
      doc = ng_xml
      return solr_doc unless doc.root['type']

      preserved_size = 0
      shelved_size = 0
      counts = Hash.new(0)                # default count is zero
      resource_type_counts = Hash.new(0)  # default count is zero
      file_roles = ::Set.new
      mime_types = ::Set.new
      first_shelved_image = nil

      doc.xpath('contentMetadata/resource').sort { |a, b| a['sequence'].to_i <=> b['sequence'].to_i }.each do |resource|
        counts['resource'] += 1
        resource_type_counts[resource['type']] += 1 if resource['type']
        resource.xpath('file').each do |file|
          counts['content_file'] += 1
          preserved_size += file['size'].to_i if file['preserve'] == 'yes'
          shelved_size += file['size'].to_i if file['shelve'] == 'yes'
          if file['shelve'] == 'yes'
            counts['shelved_file'] += 1
            first_shelved_image ||= file['id'] if file['id'] =~ /jp2$/
          end
          mime_types << file['mimetype']
          file_roles << file['role'] if file['role']
        end
      end
      solr_doc['content_type_ssim'] = doc.root['type']
      solr_doc['content_file_mimetypes_ssim'] = mime_types.to_a
      solr_doc['content_file_count_itsi'] = counts['content_file']
      solr_doc['shelved_content_file_count_itsi'] = counts['shelved_file']
      solr_doc['resource_count_itsi'] = counts['resource']
      solr_doc['preserved_size_dbtsi'] = preserved_size # double (trie) to support very large sizes
      solr_doc['shelved_size_dbtsi'] = shelved_size # double (trie) to support very large sizes
      solr_doc['resource_types_ssim'] = resource_type_counts.keys if resource_type_counts.size > 0
      solr_doc['content_file_roles_ssim'] = file_roles.to_a if file_roles.size > 0
      resource_type_counts.each do |key, count|
        solr_doc["#{key}_resource_count_itsi"] = count
      end
      # first_shelved_image is neither indexed nor multiple
      solr_doc['first_shelved_image_ss'] = first_shelved_image unless first_shelved_image.nil?
      solr_doc
    end

    ### END: READ ONLY METHODS
    ### DATSTREAM WRITING METHODS

    def unshelve_and_unpublish
      ng_xml.xpath('/contentMetadata/resource//file').each_with_index do |file_node, index|
        ng_xml_will_change! if index == 0
        file_node['publish'] = 'no'
        file_node['shelve'] = 'no'
      end
    end

    # Copies the child's resource into the parent (self) as a virtual resource.
    # Assumes the resource isn't a duplicate of an existing virtual or real resource.
    # @param [String] child_druid druid
    # @param [Nokogiri::XML::Element] child_resource
    # @return [Nokogiri::XML::Element] the new resource that was added to the contentMetadata
    def add_virtual_resource(child_druid, child_resource)
      # create a virtual resource element with attributes linked to the child and omit label
      ng_xml_will_change!
      sequence_max = ng_xml.search('//resource').map { |node| node[:sequence].to_i }.max || 0
      resource = Nokogiri::XML::Element.new('resource', ng_xml)
      resource[:sequence] = sequence_max + 1
      resource[:id] = "#{pid.gsub(/^druid:/, '')}_#{resource[:sequence]}"
      resource[:type] = child_resource[:type]

      # iterate over all the published files and link to them
      child_resource.search('file[@publish=\'yes\']').each do |file|
        resource << generate_external_file_node(child_druid, child_resource[:id], file[:id], file[:mimetype])
      end
      resource << generate_also_available_as_node(child_druid)

      # attach the virtual resource as a sibling and return
      ng_xml.root << resource
      resource
    end

    # @param [String] file_name ID of the file element
    # @param [String] publish
    # @param [String] shelve
    # @param [String] preserve
    def update_attributes(file_name, publish, shelve, preserve, attributes = {})
      ng_xml_will_change!
      file_node = ng_xml.search('//file[@id=\'' + file_name + '\']').first
      file_node['publish'] = publish
      file_node['shelve'] = shelve
      file_node['preserve'] = preserve
      attributes.each do |key, value|
        file_node[key] = value
      end
    end

    # @param file [Object] some hash-like file
    # @param old_file_id [String] unique id attribute of the file element
    def update_file(file, old_file_id)
      ng_xml_will_change!
      file_node = ng_xml.search('//file[@id=\'' + old_file_id + '\']').first
      file_node['id'] = file[:name]
      %i[md5 sha1].each do |algo|
        next if file[algo].nil?

        checksum_node = ng_xml.search('//file[@id=\'' + old_file_id + '\']/checksum[@type=\'' + algo.to_s + '\']').first
        if checksum_node.nil?
          checksum_node = Nokogiri::XML::Node.new('checksum', ng_xml)
          file_node.add_child(checksum_node)
        end
        checksum_node['type'] = algo.to_s
        checksum_node.content = file[algo]
      end

      %i[size shelve preserve publish role].each do |x|
        file_node[x.to_s] = file[x] if file[x]
      end
    end

    # @param old_name [String] unique id attribute of the file element
    # @param new_name [String] new unique id value being assigned
    # @return [Nokogiri::XML::Element] the file node
    def rename_file(old_name, new_name)
      ng_xml_will_change!
      file_node = ng_xml.search('//file[@id=\'' + old_name + '\']').first
      file_node['id'] = new_name
      file_node
    end

    # Updates old label OR creates a new one if necessary
    # @param resource_name [String] unique id attribute of the resource
    # @param new_label [String] label value being assigned
    # @return [Nokogiri::XML::Element] the resource node
    def update_resource_label(resource_name, new_label)
      ng_xml_will_change!
      node = singular_node('//resource[@id=\'' + resource_name + '\']')
      labels = node.xpath('./label')
      if labels.length == 0
        label_node = Nokogiri::XML::Node.new('label', ng_xml) # create a label
        label_node.content = new_label
        node.add_child(label_node)
      else
        labels.first.content = new_label
      end
      node
    end

    # @param resource_name [String] unique id attribute of the resource
    # @param new_type [String] type value being assigned
    def update_resource_type(resource_name, new_type)
      ng_xml_will_change!
      singular_node('//resource[@id=\'' + resource_name + '\']')['type'] = new_type
    end

    # You just *had* to have ordered lists in XML, didn't you?
    # Re-enumerate the sequence numbers affected
    # @param resource_name [String] unique id attribute of the resource
    # @param new_position [Integer, String] new sequence number of the resource, or a string that looks like one
    # @return [Nokogiri::XML::Element] the resource node
    def move_resource(resource_name, new_position)
      ng_xml_will_change!
      node = singular_node('//resource[@id=\'' + resource_name + '\']')
      position = node['sequence'].to_i
      new_position = new_position.to_i # tolerate strings as a Legacy behavior
      return node if position == new_position

      # otherwise, is the resource being moved earlier in the sequence or later?
      up = new_position > position
      others = new_position..(up ? position - 1 : position + 1) # a range
      others.each do |i|
        item = ng_xml.at_xpath('/resource[@sequence=\'' + i.to_s + '\']')
        item['sequence'] = (up ? i - 1 : i + 1).to_s # if you're going up, everything else comes down and vice versa
      end
      node['sequence'] = new_position.to_s # set the node we already had last, so we don't hit it twice!
      node
    end

    # Set the content type (e.g. "book") and the resource type (e.g. "book") for all resources
    # @param [String] old_type the old content type
    # @param [String] old_resource_type the old type for all resources
    # @param [String] new_type the new content type
    # @param [String] new_resource_type the new type for all resources
    def set_content_type(old_type, old_resource_type, new_type, new_resource_type)
      ng_xml_will_change!
      ng_xml.search('/contentMetadata[@type=\'' + old_type + '\']').each do |node|
        node['type'] = new_type
        ng_xml.search('//resource[@type=\'' + old_resource_type + '\']').each do |resource|
          resource['type'] = new_resource_type
        end
      end
    end

    # maintain AF < 8 indexing behavior
    def prefix
      ''
    end
  end
end
