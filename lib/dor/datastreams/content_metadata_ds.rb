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
        t.sequence  :path => { :attribute => 'sequence' } #, :data_type => :integer
        t.type_     :path => { :attribute => 'type' }, :index_as => [:displayable]
        t.attribute(:path => 'attr', :index_as => [:not_searchable]) do
          t.name    :path => { :attribute => 'name' }, :index_as => [:not_searchable]
        end
        t.file(:index_as => [:not_searchable]) do
          t.id_      :path => { :attribute => 'id' }
          t.mimeType :path => { :attribute => 'mimeType' }, :index_as => [:displayable]
          t.dataType :path => { :attribute => 'dataType' }, :index_as => [:displayable]
          t.size     :path => { :attribute => 'size' },     :index_as => [:displayable]    #, :data_type => :long
          t.shelve   :path => { :attribute => 'shelve' },   :index_as => [:not_searchable] #, :data_type => :boolean
          t.publish  :path => { :attribute => 'publish' },  :index_as => [:not_searchable] #, :data_type => :boolean
          t.preserve :path => { :attribute => 'preserve' }, :index_as => [:not_searchable] #, :data_type => :boolean
          t.checksum do
            t.type_  :path => { :attribute => 'type' }
          end
        end
        t.shelved_file(:path => 'file', :attributes => {:shelve=>'yes'}, :index_as => [:not_searchable]) do
          t.id_ :path => { :attribute => 'id' }, :index_as => [:displayable, :searchable]
        end
      end
      t.shelved_file_id :proxy => [:resource, :shelved_file, :id], :index_as => [:displayable, :searchable]
    end

    def public_xml
      result = ng_xml.clone
      result.xpath('/contentMetadata/resource[not(file[(@deliver="yes" or @publish="yes")])]'   ).each { |n| n.remove }
      result.xpath('/contentMetadata/resource/file[not(@deliver="yes" or @publish="yes")]'      ).each { |n| n.remove }
      result.xpath('/contentMetadata/resource/file').xpath('@preserve|@shelve|@publish|@deliver').each { |n| n.remove }
      result.xpath('/contentMetadata/resource/file/checksum').each { |n| n.remove }
      result
    end

    def add_file(file, resource_name)
      xml = ng_xml
      resource_nodes = xml.search('//resource[@id=\''+resource_name+'\']')
      raise 'resource doesnt exist.' if resource_nodes.length == 0
      node = resource_nodes.first
      file_node = Nokogiri::XML::Node.new('file', xml)
      file_node['id']       = file[:name]
      file_node['shelve']   = file[:shelve  ] ? file[:shelve  ] : ''
      file_node['publish']  = file[:publish ] ? file[:publish ] : ''
      file_node['preserve'] = file[:preserve] ? file[:preserve] : ''
      node.add_child(file_node)

      [:md5, :sha1].each do |algo|
        next unless file[algo]
        checksum_node = Nokogiri::XML::Node.new('checksum', xml)
        checksum_node['type'] = algo.to_s
        checksum_node.content = file[algo]
        file_node.add_child(checksum_node)
      end
      file_node['size'    ] = file[:size     ] if file[:size]
      file_node['mimetype'] = file[:mime_type] if file[:mime_type]
      self.content = xml.to_s
      save
    end

    def add_resource(files,resource_name, position,type = "file")
      xml = ng_xml
      raise "resource #{resource_name} already exists" if xml.search('//resource[@id=\'' + resource_name + '\']').length > 0
      max = -1
      xml.search('//resource').each do |node|
        max = node['sequence'].to_i if node['sequence'].to_i > max
      end
      #renumber all of the resources that will come after the newly added one
      while max > position do
        node = xml.search('//resource[@sequence=\'' + position + '\']')
        if node.length > 0
          node = node.first
          node[sequence] = max + 1
        end
        max -= 1
      end
      node = Nokogiri::XML::Node.new('resource',xml)
      node['sequence'] = position.to_s
      node['id'] = resource_name
      node['type'] = type
      files.each do |file|
        file_node = Nokogiri::XML::Node.new('file', xml)
        file_node['shelve'  ] = file[:shelve  ] ? file[:shelve  ] : ''
        file_node['publish' ] = file[:publish ] ? file[:publish ] : ''
        file_node['preserve'] = file[:preserve] ? file[:preserve] : ''
        file_node['id'      ] = file[:name]
        node.add_child(file_node)
        [:md5, :sha1].each do |algo|
          next unless file[algo]
          checksum_node = Nokogiri::XML::Node.new('checksum', xml)
          checksum_node['type'] = algo.to_s
          checksum_node.content = file[algo]
          file_node.add_child(checksum_node)
        end
        file_node['size'] = file[:size] if file[:size]
      end
      xml.search('//contentMetadata').first.add_child(node)
      self.content = xml.to_s
      save
    end

    def remove_resource resource_name
      xml = ng_xml
      position = -1
      resources = xml.search('//resource[@id=\'' + resource_name + '\']')
      raise 'Resource is missing or duplicated!' if resources.length != 1
      position = resources.first['sequence']
      resources.first.remove
      position = position.to_i + 1
      while true
        res = xml.search('//resource[@sequence=\'' + position.to_s + '\']')
        break if res.length == 0
        res['sequence'] = position.to_s
        position += 1
      end
      self.content = xml.to_s
      save
    end

    def remove_file file_name
      xml = ng_xml
      xml.search('//file[@id=\'' + file_name + '\']').each do |node|
        node.remove
      end
      self.content = xml.to_s
      save
    end

    def update_attributes file_name, publish, shelve, preserve
      xml = ng_xml
      file_node = xml.search('//file[@id=\'' + file_name + '\']').first
      file_node['shelve'  ] = shelve
      file_node['publish' ] = publish
      file_node['preserve'] = preserve
      self.content = xml.to_s
      save
    end

    def update_file file, old_file_id
      xml = ng_xml
      file_node = xml.search('//file[@id=\'' + old_file_id + '\']').first
      file_node['id'] = file[:name]
      unless file[:md5].nil?
        checksum_node = xml.search('//file[@id=\'' + old_file_id + '\']/checksum[@type=\'md5\']').first
        if checksum_node.nil?
          checksum_node = Nokogiri::XML::Node.new('checksum', xml)
          file_node.add_child(checksum_node)
        end
        checksum_node['type'] = 'md5'
        checksum_node.content = file[:md5]
      end
      unless file[:sha1].nil?
        checksum_node = xml.search('//file[@id=\'' + old_file_id + '\']/checksum[@type=\'sha1\']').first
        if checksum_node.nil?
          checksum_node = Nokogiri::XML::Node.new('checksum', xml)
          file_node.add_child(checksum_node)
        end
        checksum_node['type'] = 'sha1'
        checksum_node.content = file[:sha1]
      end

      file_node['size'    ] = file[:size    ] if file[:size]
      file_node['shelve'  ] = file[:shelve  ] if file[:shelve]
      file_node['preserve'] = file[:preserve] if file[:preserve]
      file_node['publish' ] = file[:publish ] if file[:publish]
      self.content = xml.to_s
      save
    end

    # Terminology-based solrization is going to be painfully slow for large
    # contentMetadata streams. Just select the relevant elements instead.
    def to_solr(solr_doc = {}, *args)
      doc = ng_xml
      if doc.root['type']
        shelved_file_count = 0
        content_file_count = 0
        resource_type_counts = {}
        resource_count = 0
        preserved_size = 0
        first_shelved_image = nil
        add_solr_value(solr_doc, "content_type", doc.root['type'], :string, [:facetable])
        doc.xpath('contentMetadata/resource').sort { |a, b| a['sequence'].to_i <=> b['sequence'].to_i }.each do |resource|
          resource_count += 1
          if resource['type']
            if resource_type_counts[resource['type']]
              resource_type_counts[resource['type']] += 1
            else
              resource_type_counts[resource['type']] = 1
            end
          end
          resource.xpath('file').each do |file|
            content_file_count += 1
            if file['shelve'] == 'yes'
              shelved_file_count += 1
              first_shelved_image = file['id'] if first_shelved_image.nil? && file['id'].match(/jp2$/)
            end
            preserved_size += file['size'].to_i if file['preserve'] == 'yes'
          end
        end
        add_solr_value(solr_doc, 'content_file_count', content_file_count.to_s, :string, [:searchable, :displayable])
        add_solr_value(solr_doc, 'shelved_content_file_count', shelved_file_count.to_s, :string, [:searchable, :displayable])
        add_solr_value(solr_doc, 'resource_count', resource_count.to_s, :string, [:searchable, :displayable])
        add_solr_value(solr_doc, 'preserved_size', preserved_size.to_s, :string, [:searchable, :displayable])
        resource_type_counts.each do |key, count|
          add_solr_value(solr_doc, key + '_resource_count', count.to_s, :string, [:searchable, :displayable])
        end
        unless first_shelved_image.nil?
          add_solr_value(solr_doc, 'first_shelved_image', first_shelved_image, :string, [:displayable])
        end
      end
      solr_doc
    end

    def rename_file old_name, new_name
      xml = ng_xml
      file_node = xml.search('//file[@id=\'' + old_name + '\']').first
      file_node['id'] = new_name
      self.content = xml.to_s
      save
    end

    def update_resource_label resource_name, new_label
      xml = ng_xml
      resource_node = xml.search('//resource[@id=\'' + resource_name + '\']')
      raise 'Resource not found or duplicate found.' unless resource_node.length == 1
      labels = xml.search('//resource[@id=\'' + resource_name + '\']/label')
      if labels.length == 0
        #create a label
        label_node = Nokogiri::XML::Node.new('label', xml)
        label_node.content = new_label
        resource_node.first.add_child(label_node)
      else
        labels.first.content = new_label
      end
    end

    def update_resource_type resource, new_type
      xml = ng_xml
      resource_node = xml.search('//resource[@id=\'' + resource_name + '\']')
      raise 'Resource not found or duplicate found.' unless resource_node.length == 1
      resource_node.first['type'] = new_type
    end

    def move_resource resource_name, new_position
      xml = ng_xml
      file_node = xml.search('//resource[@id=\''+resource_name+'\']')
      raise 'Resource not found or duplicate found.' unless file_node.length == 1
      position = file_node.first['sequence'].to_i
      # is the resource being moved earlier in the sequence or later?
      new_position = new_position.to_i
      if new_position > position
        counter = position
        while true
          break if counter == position
          item = xml.search('/resource[@id=\'' + counter.to_s + '\']').first
          counter += 1
          item['sequence'] = counter.to_s
        end
      else
        counter = position
        while true
          break if counter == new_position
          item = xml.search('/resource[@id=\'' + counter.to_s + '\']').first
          counter -= 1
          item['sequence'] = counter.to_s
        end
      end
    end

    # Set the content type to and the resource types for all resources
    # @param new_type [String] the new content type, ex book
    # @param new_resource_type [String] the new type for all resources, ex book
    def set_content_type old_type, old_resource_type, new_type, new_resource_type
      xml = ng_xml
      xml.search('/contentMetadata[@type=\'' + old_type + '\']').each do |node|
        node['type'] = new_type
        xml.search('//resource[@type=\'' + old_resource_type + '\']').each do |resource|
          resource['type'] = new_resource_type
        end
      end
      self.content = xml.to_s
    end
  end

end
