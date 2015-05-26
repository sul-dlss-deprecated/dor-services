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
        t.sequence  :path => { :attribute => 'sequence' }#, :data_type => :integer
        t.type_     :path => { :attribute => 'type' }, :index_as => [:displayable]
        t.attribute(:path => 'attr', :index_as => [:not_searchable]) do
          t.name    :path => { :attribute => 'name' }, :index_as => [:not_searchable]
        end
        t.file(:index_as => [:not_searchable]) do
          t.id_      :path => { :attribute => 'id' }
          t.mimeType :path => { :attribute => 'mimeType' }, :index_as => [:displayable]
          t.dataType :path => { :attribute => 'dataType' }, :index_as => [:displayable]
          t.size     :path => { :attribute => 'size'     }, :index_as => [:displayable]#, :data_type => :long
          t.shelve   :path => { :attribute => 'shelve'   }, :index_as => [:not_searchable]#, :data_type => :boolean
          t.publish  :path => { :attribute => 'publish'  }, :index_as => [:not_searchable]#, :data_type => :boolean
          t.preserve :path => { :attribute => 'preserve' }, :index_as => [:not_searchable]#, :data_type => :boolean
          t.checksum do
            t.type_ :path => { :attribute => 'type' }
          end
        end
        t.shelved_file(:path => 'file', :attributes => {:shelve=>'yes'}, :index_as => [:not_searchable]) do
          t.id_ :path => { :attribute => 'id' }, :index_as => [:displayable, :searchable]
        end
      end
      t.shelved_file_id :proxy => [:resource, :shelved_file, :id], :index_as => [:displayable, :searchable]
    end

    def public_xml
      result = self.ng_xml.clone
      result.xpath('/contentMetadata/resource[not(file[(@deliver="yes" or @publish="yes")])]'   ).each { |n| n.remove }
      result.xpath('/contentMetadata/resource/file[not(@deliver="yes" or @publish="yes")]'      ).each { |n| n.remove }
      result.xpath('/contentMetadata/resource/file').xpath('@preserve|@shelve|@publish|@deliver').each { |n| n.remove }
      result.xpath('/contentMetadata/resource/file/checksum'                                    ).each { |n| n.remove }
      result
    end
    def add_file(file, resource_name)
      xml=self.ng_xml
      resource_nodes = xml.search('//resource[@id=\''+resource_name+'\']')
      raise 'resource doesnt exist.' if resource_nodes.length==0
      node=resource_nodes.first
      file_node=Nokogiri::XML::Node.new('file',xml)
      file_node['id']=file[:name]
      file_node['shelve'  ] = file[:shelve  ] ? file[:shelve  ] : ''
      file_node['publish' ] = file[:publish ] ? file[:publish ] : ''
      file_node['preserve'] = file[:preserve] ? file[:preserve] : ''
      node.add_child(file_node)

      if file[:md5]
        checksum_node=Nokogiri::XML::Node.new('checksum',xml)
        checksum_node['type']='md5'
        checksum_node.content=file[:md5]
        file_node.add_child(checksum_node)
      end
      if file[:sha1]
        checksum_node=Nokogiri::XML::Node.new('checksum',xml)
        checksum_node['type']='sha1'
        checksum_node.content=file[:sha1]
        file_node.add_child(checksum_node)
      end
      if file[:size]
        file_node['size']=file[:size]
      end
      if file[:mime_type]
        file_node['mimetype']=file[:mime_type]
      end
      self.content=xml.to_s
    end

    def add_resource(files,resource_name, position,type="file")
      xml=self.ng_xml
      if xml.search('//resource[@id=\''+resource_name+'\']').length>0
        raise 'resource '+resource_name+' already exists'
      end
      node=nil

      max = xml.search('//resource').map{ |node| node['sequence'].to_i }.max
      #renumber all of the resources that will come after the newly added one
      while max>position do
        node=xml.search('//resource[@sequence=\'' + position.to_s + '\']')
        node.first[sequence]=max+1 if node.length>0
        max-=1
      end
      node=Nokogiri::XML::Node.new('resource',xml)
      node['sequence']=position.to_s
      node['id']=resource_name
      node['type']=type
      files.each do |file|
        file_node=Nokogiri::XML::Node.new('file',xml)
        %w[shelve publish preserve].each {|x| file_node[x] = file[x.to_sym] ? file[x.to_sym] : '' }
        file_node['id'] = file[:name]
        node.add_child(file_node)

        [:md5, :sha1].each { |algo|
          next if file[algo].nil?
          checksum_node = Nokogiri::XML::Node.new('checksum',xml)
          checksum_node['type'] = algo.to_s
          checksum_node.content = file[algo]
          file_node.add_child(checksum_node)
        }
        file_node['size'] = file[:size] if file[:size]
      end
      xml.search('//contentMetadata').first.add_child(node)
      self.content=xml.to_s
    end

    def remove_resource resource_name
      xml=self.ng_xml
      node = singular_node('//resource[@id=\''+resource_name+'\']')
      position = node['sequence'].to_i+1
      node.remove
      while true
        res=xml.search('//resource[@sequence=\''+position.to_s+'\']')
        break if res.length==0
        res['sequence']=position.to_s
        position=position+1
      end
      self.content=xml.to_s
    end

    def remove_file file_name
      xml=self.ng_xml
      xml.search('//file[@id=\''+file_name+'\']').each do |node|
        node.remove
      end
      self.content=xml.to_s
    end
    def update_attributes file_name, publish, shelve, preserve
      xml=self.ng_xml
      file_node=xml.search('//file[@id=\''+file_name+'\']').first
      file_node['shelve'  ]=shelve
      file_node['publish' ]=publish
      file_node['preserve']=preserve
      self.content=xml.to_s
    end
    def update_file file, old_file_id
      xml=self.ng_xml
      file_node=xml.search('//file[@id=\''+old_file_id+'\']').first
      file_node['id']=file[:name]
      [:md5, :sha1].each { |algo|
        next if file[algo].nil?
        checksum_node = xml.search('//file[@id=\''+old_file_id+'\']/checksum[@type=\'' + algo.to_s + '\']').first
        if checksum_node.nil?
          checksum_node = Nokogiri::XML::Node.new('checksum',xml)
          file_node.add_child(checksum_node)
        end
        checksum_node['type'] = algo.to_s
        checksum_node.content = file[algo]
      }

      [:size, :shelve, :preserve, :publish].each{ |x|
        file_node[x.to_s] = file[x] if file[x]
      }
      self.content=xml.to_s
    end

    # Terminology-based solrization is going to be painfully slow for large
    # contentMetadata streams. Just select the relevant elements instead.
    def to_solr(solr_doc=Hash.new, *args)
      doc = self.ng_xml
      if doc.root['type']
        shelved_file_count=0
        content_file_count=0
        resource_count=0
        preserved_size=0
        resource_type_counts=Hash.new(0)  # default count
        first_shelved_image=nil
        add_solr_value(solr_doc, "content_type", doc.root['type'], :string, [:facetable, :symbol])
        doc.xpath('contentMetadata/resource').sort { |a,b| a['sequence'].to_i <=> b['sequence'].to_i }.each do |resource|
          resource_count+=1
          resource_type_counts[resource['type']]+=1 if(resource['type'])
          resource.xpath('file').each do |file|
            content_file_count+=1
            if file['shelve'] == 'yes'
              shelved_file_count+=1
              if first_shelved_image.nil? && file['id'].match(/jp2$/)
                first_shelved_image=file['id']
              end
            end
            preserved_size += file['size'].to_i if file['preserve'] == 'yes'
          end
        end
        add_solr_value(solr_doc, "content_file_count", content_file_count.to_s, :string, [:searchable, :displayable])
        add_solr_value(solr_doc, "shelved_content_file_count", shelved_file_count.to_s, :string, [:searchable, :displayable])
        add_solr_value(solr_doc, "resource_count", resource_count.to_s, :string, [:searchable, :displayable])
        add_solr_value(solr_doc, "preserved_size", preserved_size.to_s, :string, [:searchable, :displayable])
        resource_type_counts.each do |key, count|
          add_solr_value(solr_doc, "resource_types", key, :string, [:symbol])
          add_solr_value(solr_doc, key+"_resource_count", count.to_s, :string, [:searchable, :displayable])
        end
        unless first_shelved_image.nil?
          add_solr_value(solr_doc, "first_shelved_image", first_shelved_image, :string, [:displayable])
        end
      end
      solr_doc
    end

    #@param old_name [String] unique id attribute of the file element
    #@param new_name [String] new unique id value being assigned
    #@return [Nokogiri::XML::Element] the file node
    def rename_file old_name, new_name
      xml=self.ng_xml
      file_node=xml.search('//file[@id=\''+old_name+'\']').first
      content_will_change!
      file_node['id']=new_name
      self.content=xml.to_s
      file_node
    end

    #Updates old label OR creates a new one if necessary
    #@param resource_name [String] unique id attribute of the resource
    #@param new_label [String] label value being assigned
    #@return [Nokogiri::XML::Element] the resource node
    def update_resource_label resource_name, new_label
      node = singular_node('//resource[@id=\''+resource_name+'\']')
      labels = node.xpath('./label')
      content_will_change!
      if(labels.length==0)
        #create a label
        label_node = Nokogiri::XML::Node.new('label',self.ng_xml)
        label_node.content=new_label
        node.add_child(label_node)
      else
        labels.first.content=new_label
      end
      self.content=self.ng_xml.to_s
      return node
    end

    #@param resource_name [String] unique id attribute of the resource
    #@param new_type [String] type value being assigned
    def update_resource_type resource_name, new_type
      singular_node('//resource[@id=\''+resource_name+'\']')['type']=new_type
      content_will_change!
      self.content=self.ng_xml.to_s
    end

    #You just *had* to have ordered lists in XML, didn't you?
    #Re-enumerate the sequence numbers affected
    #@param resource_name [String] unique id attribute of the resource
    #@param new_position [Integer, String] new sequence number of the resource, or a string that looks like one
    #@return [Nokogiri::XML::Element] the resource node
    def move_resource resource_name, new_position
      node = singular_node('//resource[@id=\''+resource_name+'\']')
      position = node['sequence'].to_i
      new_position = new_position.to_i              # tolerate strings as a Legacy behavior
      return node if position == new_position
      content_will_change!
      #otherwise, is the resource being moved earlier in the sequence or later?
      up = new_position>position
      others = new_position..(up ? position-1 : position+1)  # a range
      others.each do |i|
        item = self.ng_xml.at_xpath('/resource[@sequence=\''+i.to_s+'\']')
        item['sequence'] = (up ? i-1 : i+1).to_s    # if you're going up, everything else comes down and vice versa
      end
      node['sequence'] = new_position.to_s          # set the node we already had last, so we don't hit it twice!
      self.content=self.ng_xml.to_s
      return node
    end

    #Set the content type and the resource types for all resources
    #@param new_type [String] the new content type, ex book
    #@param new_resource_type [String] the new type for all resources, ex book
    def set_content_type old_type, old_resource_type, new_type, new_resource_type
      xml=self.ng_xml
      return if old_type == new_type && old_resource_type == new_resource_type
      content_will_change!
      xml.search('/contentMetadata[@type=\''+old_type+'\']').each do |node|
        node['type']=new_type
        xml.search('//resource[@type=\''+old_resource_type+'\']').each do |resource|
          resource['type']=new_resource_type
        end
      end
      self.content=xml.to_s
    end

    # Only use this when you want the behavior of raising an exception if anything besides exactly one matching node
    # is found.  Otherwise just use .xpath, .at_xpath or .search.
    #@param xpath [String] accessor invocation for Nokogiri xpath
    #@return [Nokogiri::XML::Element] the matched element
    def singular_node xpath
      node = self.ng_xml.search(xpath)
      len  = node.length
      raise "#{xpath} not found" if len < 1
      raise "#{xpath} duplicated: #{len} found" if len != 1
      node.first
    end
  end

end
