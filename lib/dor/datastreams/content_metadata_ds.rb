module Dor
  class ContentMetadataDS < ActiveFedora::OmDatastream
    include Upgradable
    include SolrDocHelper

    set_terminology do |t|
      t.root        :path => 'contentMetadata',          :index_as => [:not_searchable]
      t.contentType :path => '/contentMetadata/@type',   :index_as => [:not_searchable]
      t.stacks      :path => '/contentMetadata/@stacks', :index_as => [:not_searchable]
      t.resource(:index_as => [:not_searchable]) do
        t.id_       :path => { :attribute => 'id' }
        t.sequence  :path => { :attribute => 'sequence' } # , :data_type => :integer
        t.type_     :path => { :attribute => 'type' }, :index_as => [:displayable]
        t.attribute(:path => 'attr', :index_as => [:not_searchable]) do
          t.name    :path => { :attribute => 'name' }, :index_as => [:not_searchable]
        end
        t.file(:index_as => [:not_searchable]) do
          t.id_      :path => { :attribute => 'id' }
          t.mimeType :path => { :attribute => 'mimeType' }, :index_as => [:displayable]
          t.dataType :path => { :attribute => 'dataType' }, :index_as => [:displayable]
          t.size     :path => { :attribute => 'size'     }, :index_as => [:displayable] # , :data_type => :long
          t.shelve   :path => { :attribute => 'shelve'   }, :index_as => [:not_searchable] # , :data_type => :boolean
          t.publish  :path => { :attribute => 'publish'  }, :index_as => [:not_searchable] # , :data_type => :boolean
          t.preserve :path => { :attribute => 'preserve' }, :index_as => [:not_searchable] # , :data_type => :boolean
          t.checksum do
            t.type_ :path => { :attribute => 'type' }
          end
        end
        t.shelved_file(:path => 'file', :attributes => {:shelve => 'yes'}, :index_as => [:not_searchable]) do
          t.id_ :path => { :attribute => 'id' }, :index_as => [:displayable, :stored_searchable]
        end
      end
      t.shelved_file_id :proxy => [:resource, :shelved_file, :id], :index_as => [:displayable, :stored_searchable]
    end

    def public_xml
      result = ng_xml.clone
      result.xpath('/contentMetadata/resource[not(file[(@deliver="yes" or @publish="yes")])]'   ).each { |n| n.remove }
      result.xpath('/contentMetadata/resource/file[not(@deliver="yes" or @publish="yes")]'      ).each { |n| n.remove }
      result.xpath('/contentMetadata/resource/file').xpath('@preserve|@shelve|@publish|@deliver').each { |n| n.remove }
      result.xpath('/contentMetadata/resource/file/checksum'                                    ).each { |n| n.remove }
      result
    end
    def add_file(file, resource_name)
      xml = ng_xml
      resource_nodes = xml.search('//resource[@id=\'' + resource_name + '\']')
      raise 'resource doesnt exist.' if resource_nodes.length == 0
      node = resource_nodes.first
      file_node = Nokogiri::XML::Node.new('file', xml)
      file_node['id'] = file[:name]
      file_node['shelve'  ] = file[:shelve  ] ? file[:shelve  ] : ''
      file_node['publish' ] = file[:publish ] ? file[:publish ] : ''
      file_node['preserve'] = file[:preserve] ? file[:preserve] : ''
      node.add_child(file_node)

      [:md5, :sha1].each do |algo|
        next unless file[algo]
        checksum_node = Nokogiri::XML::Node.new('checksum', xml)
        checksum_node['type'] = algo.to_s
        checksum_node.content = file[algo]
        file_node.add_child(checksum_node)
      end
      file_node['size'    ] = file[:size     ] if file[:size     ]
      file_node['mimetype'] = file[:mime_type] if file[:mime_type]
      self.content = xml.to_s
      save
    end

    #
    # Generates the XML tree for externalFile references. For example,
    #
    #     <externalFile objectId="druid:mn123pq4567" resourceId="Image01" fileId="image_01.jp2000" mimetype="image/jp2" />
    #
    # @param [String] objectId the linked druid
    # @param [String] resourceId the linked druid's resource identifier
    # @param [String] fileId the linked druid's resource's file identifier
    # @param [String] mimetype the file's MIME type
    #
    # @return [Nokogiri::XML::Element]
    #
    def generate_external_file_node(objectId, resourceId, fileId, mimetype)
      externalFile = ng_xml.create_element 'externalFile'
      externalFile[:objectId] = objectId
      externalFile[:resourceId] = resourceId
      externalFile[:fileId] = fileId
      externalFile[:mimetype] = mimetype
      externalFile
    end

    #
    # Generates the XML tree for virtual resource relationship reference. For example,
    #
    #     <relationship type="alsoAvailableAs" objectId="druid:mn123pq4567" />
    #
    # @param [String] objectId the linked druid
    #
    # @return [Nokogiri::XML::Element]
    #
    def generate_also_available_as_node(objectId)
      relationship = ng_xml.create_element 'relationship'
      relationship[:type] = 'alsoAvailableAs'
      relationship[:objectId] = objectId
      relationship
    end

    #
    # Copies the child's resource into the parent (self) as a virtual resource.
    # Assumes the resource isn't a duplicate of an existing virtual or real resource.
    #
    # @param [String] child_druid druid
    # @param [Nokogiri::XML::Element] child_resource
    #
    # @return [Nokogiri::XML::Element] the new resource that was added to the contentMetadata
    #
    def add_virtual_resource(child_druid, child_resource)
      # create a virtual resource element with attributes linked to the child and omit label
      sequence_max = self.ng_xml.search('//resource').map{ |node| node[:sequence].to_i }.max
      resource = Nokogiri::XML::Element.new('resource', self.ng_xml)
      resource[:sequence] = sequence_max + 1
      resource[:id] = "#{self.pid.gsub(/^druid:/, '')}_#{resource[:sequence]}"
      resource[:type] = child_resource[:type]

      # iterate over all the published files and link to them
      child_resource.search('file[@publish=\'yes\']').each do |file|
        resource << generate_external_file_node(child_druid, child_resource[:id], file[:id], file[:mimetype])
      end
      resource << generate_also_available_as_node(child_druid)

      # save the virtual resource as a sibling and return
      self.ng_xml.root << resource
      resource
    end

    def add_resource(files, resource_name, position, type = 'file')
      xml = ng_xml
      raise "resource #{resource_name} already exists" if xml.search('//resource[@id=\'' + resource_name + '\']').length > 0
      max = xml.search('//resource').map { |node| node['sequence'].to_i }.max
      # renumber all of the resources that will come after the newly added one
      while max > position
        node = xml.search('//resource[@sequence=\'' + position + '\']')
        node.first[sequence] = max + 1 if node.length > 0
        max -= 1
      end
      node = Nokogiri::XML::Node.new('resource', xml)
      node['sequence'] = position.to_s
      node['id'] = resource_name
      node['type'] = type
      files.each do |file|
        file_node = Nokogiri::XML::Node.new('file', xml)
        %w[shelve publish preserve].each {|x| file_node[x] = file[x.to_sym] ? file[x.to_sym] : '' }
        file_node['id'] = file[:name]
        node.add_child(file_node)

        [:md5, :sha1].each { |algo|
          next if file[algo].nil?
          checksum_node = Nokogiri::XML::Node.new('checksum', xml)
          checksum_node['type'] = algo.to_s
          checksum_node.content = file[algo]
          file_node.add_child(checksum_node)
        }
        file_node['size'] = file[:size] if file[:size]
      end
      xml.search('//contentMetadata').first.add_child(node)
      self.content = xml.to_s
      save
    end

    def remove_resource(resource_name)
      xml = ng_xml
      node = singular_node('//resource[@id=\'' + resource_name + '\']')
      position = node['sequence'].to_i + 1
      node.remove
      loop do
        res = xml.search('//resource[@sequence=\'' + position.to_s + '\']')
        break if res.length == 0
        res['sequence'] = position.to_s
        position += 1
      end
      self.content = xml.to_s
      save
    end

    def remove_file(file_name)
      xml = ng_xml
      xml.search('//file[@id=\'' + file_name + '\']').each do |node|
        node.remove
      end
      self.content = xml.to_s
      save
    end
    def update_attributes(file_name, publish, shelve, preserve)
      xml = ng_xml
      file_node = xml.search('//file[@id=\'' + file_name + '\']').first
      file_node['shelve'  ] = shelve
      file_node['publish' ] = publish
      file_node['preserve'] = preserve
      self.content = xml.to_s
      save
    end
    def update_file(file, old_file_id)
      xml = ng_xml
      file_node = xml.search('//file[@id=\'' + old_file_id + '\']').first
      file_node['id'] = file[:name]
      [:md5, :sha1].each { |algo|
        next if file[algo].nil?
        checksum_node = xml.search('//file[@id=\'' + old_file_id + '\']/checksum[@type=\'' + algo.to_s + '\']').first
        if checksum_node.nil?
          checksum_node = Nokogiri::XML::Node.new('checksum', xml)
          file_node.add_child(checksum_node)
        end
        checksum_node['type'] = algo.to_s
        checksum_node.content = file[algo]
      }

      [:size, :shelve, :preserve, :publish].each { |x|
        file_node[x.to_s] = file[x] if file[x]
      }
      self.content = xml.to_s
      save
    end

    # Terminology-based solrization is going to be painfully slow for large
    # contentMetadata streams. Just select the relevant elements instead.
    # TODO: Call super()?
    def to_solr(solr_doc = {}, *args)
      doc = ng_xml
      return solr_doc unless doc.root['type']

      preserved_size = 0
      counts = Hash.new(0)                # default count is zero
      resource_type_counts = Hash.new(0)  # default count is zero
      first_shelved_image = nil

      doc.xpath('contentMetadata/resource').sort { |a, b| a['sequence'].to_i <=> b['sequence'].to_i }.each do |resource|
        counts['resource'] += 1
        resource_type_counts[resource['type']] += 1 if resource['type']
        resource.xpath('file').each do |file|
          counts['content_file'] += 1
          preserved_size += file['size'].to_i if file['preserve'] == 'yes'
          next unless file['shelve'] == 'yes'
          counts['shelved_file'] += 1
          first_shelved_image ||= file['id'] if file['id'].match(/jp2$/)
        end
      end
      solr_doc['content_type_ssim'              ] = doc.root['type']
      solr_doc['content_file_count_itsi'        ] = counts['content_file']
      solr_doc['shelved_content_file_count_itsi'] = counts['shelved_file']
      solr_doc['resource_count_itsi'            ] = counts['resource']
      solr_doc['preserved_size_dbtsi'           ] = preserved_size        # double (trie) to support very large sizes
      solr_doc['resource_types_ssim'            ] = resource_type_counts.keys if resource_type_counts.size > 0
      resource_type_counts.each do |key, count|
        solr_doc["#{key}_resource_count_itsi"] = count
      end
      # first_shelved_image is neither indexed nor multiple
      solr_doc['first_shelved_image_ss'] = first_shelved_image unless first_shelved_image.nil?
      solr_doc
    end

    # @param old_name [String] unique id attribute of the file element
    # @param new_name [String] new unique id value being assigned
    # @return [Nokogiri::XML::Element] the file node
    def rename_file(old_name, new_name)
      xml = ng_xml
      file_node = xml.search('//file[@id=\'' + old_name + '\']').first
      file_node['id'] = new_name
      self.content = xml.to_s
      save
    end

    # Updates old label OR creates a new one if necessary
    # @param resource_name [String] unique id attribute of the resource
    # @param new_label [String] label value being assigned
    # @return [Nokogiri::XML::Element] the resource node
    def update_resource_label(resource_name, new_label)
      node = singular_node('//resource[@id=\'' + resource_name + '\']')
      labels = node.xpath('./label')
      if (labels.length == 0)
        # create a label
        label_node = Nokogiri::XML::Node.new('label', ng_xml)
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
      singular_node('//resource[@id=\'' + resource_name + '\']')['type'] = new_type
    end

    # You just *had* to have ordered lists in XML, didn't you?
    # Re-enumerate the sequence numbers affected
    # @param resource_name [String] unique id attribute of the resource
    # @param new_position [Integer, String] new sequence number of the resource, or a string that looks like one
    # @return [Nokogiri::XML::Element] the resource node
    def move_resource(resource_name, new_position)
      node = singular_node('//resource[@id=\'' + resource_name + '\']')
      position = node['sequence'].to_i
      new_position = new_position.to_i              # tolerate strings as a Legacy behavior
      return node if position == new_position
      # otherwise, is the resource being moved earlier in the sequence or later?
      up = new_position > position
      others = new_position..(up ? position - 1 : position + 1)  # a range
      others.each do |i|
        item = ng_xml.at_xpath('/resource[@sequence=\'' + i.to_s + '\']')
        item['sequence'] = (up ? i - 1 : i + 1).to_s    # if you're going up, everything else comes down and vice versa
      end
      node['sequence'] = new_position.to_s          # set the node we already had last, so we don't hit it twice!
      node
    end

    # Set the content type and the resource types for all resources
    # @param new_type [String] the new content type, ex book
    # @param new_resource_type [String] the new type for all resources, ex book
    def set_content_type(old_type, old_resource_type, new_type, new_resource_type)
      xml = ng_xml
      xml.search('/contentMetadata[@type=\'' + old_type + '\']').each do |node|
        node['type'] = new_type
        xml.search('//resource[@type=\'' + old_resource_type + '\']').each do |resource|
          resource['type'] = new_resource_type
        end
      end
      self.content = xml.to_s
    end

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
  end

end
