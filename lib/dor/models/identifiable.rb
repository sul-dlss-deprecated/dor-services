module Dor
  module Identifiable
    extend ActiveSupport::Concern
    include SolrDocHelper
    include Eventable
    include Upgradable

    included do
      has_metadata :name => "DC", :type => SimpleDublinCoreDs, :label => 'Dublin Core Record for self object'
      has_metadata :name => "identityMetadata", :type => Dor::IdentityMetadataDS, :label => 'Identity Metadata'
    end

    module ClassMethods
      attr_reader :object_type
      def has_object_type str
        @object_type = str
        Dor.registered_classes[str] = self
      end
    end

    def initialize attrs={}
      if Dor::Config.suri.mint_ids
        unless attrs[:pid]
          attrs = attrs.merge!({:pid=>Dor::SuriService.mint_id, :new_object => true})
        end
      end
      super
    end

    # helper method to get the tags as an array
    def tags
      self.identityMetadata.tag
    end

    # helper method to get just the content type tag
    def content_type_tag
      content_tag=tags.select {|tag| tag.include?('Process : Content Type')}
      content_tag.size == 1 ? content_tag[0].split(':').last.strip : ""
    end

    # Syntactic sugar for identifying applied DOR Concerns
    # e.g., obj.is_identifiable? is the same as obj.is_a?(Dor::Identifiable)
    def method_missing sym, *args
      if sym.to_s =~ /^is_(.+)\?$/
        begin
          klass = Dor.const_get $1.capitalize.to_sym
          return self.is_a?(klass)
        rescue NameError
          return false
        end
      else
        super
      end
    end

    ## Module-level variables, shared between ALL mixin includers!
    # used for caching found values
    @@collection_hash={}
    @@apo_hash={}
    @@hydrus_apo_hash={}
    @@hydrus_collection_hash={}

    def to_solr(solr_doc=Hash.new, *args)
      self.assert_content_model
      super(solr_doc, *args)

      solr_doc[Dor::INDEX_VERSION_FIELD] = Dor::VERSION
      solr_doc['indexed_at_dtsi' ] = Time.now.utc.xmlschema
      solr_doc['indexed_day_dtsi'] = Time.now.beginning_of_day.utc.xmlschema  # technically unnecessary, but convenient

      datastreams.values.each do |ds|
        add_solr_value(solr_doc, 'ds_specs', ds.datastream_spec_string, :string, [:displayable]) unless ds.new?
      end

      add_solr_value(solr_doc, 'title_sort', self.label, :string, [:sortable])

      rels_doc = Nokogiri::XML(self.datastreams['RELS-EXT'].content)
      apos = rels_doc.search('//rdf:RDF/rdf:Description/hydra:isGovernedBy', 'hydra' => 'http://projecthydra.org/ns/relations#', 'fedora' => 'info:fedora/fedora-system:def/relations-external#', 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#')
      collections = rels_doc.search('//rdf:RDF/rdf:Description/fedora:isMemberOfCollection', 'fedora' => 'info:fedora/fedora-system:def/relations-external#', 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#')
      solrize_related_obj_titles(solr_doc, apos, @@apo_hash, @@hydrus_apo_hash, "apo_title", "hydrus_apo_title")
      solrize_related_obj_titles(solr_doc, collections, @@collection_hash, @@hydrus_collection_hash, "collection_title", "hydrus_collection_title")

      solr_doc["metadata_source_ssi"] = self.identity_metadata_source

      return solr_doc
    end

    #@return [String] calculated value for Solr index
    def identity_metadata_source
      if self.identityMetadata.otherId('catkey').first ||
         self.identityMetadata.otherId('barcode').first
        'Symphony'
      elsif self.identityMetadata.otherId('mdtoolkit').first
        'Metadata Toolkit'
      else
        'DOR'
      end
    end

    def set_source_id(source_id)
      self.identityMetadata.sourceId = source_id
    end

    def add_other_Id(type,val)
      if self.identityMetadata.otherId(type).length>0
        raise 'There is an existing entry for '+type+', consider using update_other_Id().'
      end
      self.identityMetadata.add_otherId(type+':'+val)
    end

    def update_other_Id(type, new_val, val=nil)
      updated=false
      self.identityMetadata.ng_xml.search('//otherId[@name=\''+type+'\']').each do |node|
        if node.content==val || val.nil?
          node.content=new_val
          updated=true
        end
      end
      return updated
    end

    def remove_other_Id(type, val=nil)
      removed=false
      self.identityMetadata.ng_xml.search('//otherId[@name=\''+type+'\']').each do |node|
        if node.content===val || val.nil?
          node.remove
          removed=true
        end
      end
      return removed
    end

    # turns a tag string into an array with one element per tag part.
    # split on ":", disregard leading and trailing whitespace on tokens.
    def split_tag_to_arr(tag_str)
      return tag_str.split(":").map {|str| str.strip}
    end

    # turn a tag array back into a tag string with a standard format
    def normalize_tag_arr(tag_arr)
      return tag_arr.join(' : ')
    end

    # take a tag string and return a normalized tag string
    def normalize_tag(tag_str)
      return normalize_tag_arr(split_tag_to_arr(tag_str))
    end

    # take a proposed tag string and a list of the existing tags for the object being edited.  if
    # the proposed tag is valid, return it in normalized form.  if not, raise an exception with an
    # explanatory message.
    def validate_and_normalize_tag(tag_str, existing_tag_list)
      tag_arr = validate_tag_format(tag_str)

      # note that the comparison for duplicate tags is case-insensitive, but we don't change case as part of the normalized version
      # we return, because we want to preserve the user's intended case.
      normalized_tag = normalize_tag_arr(tag_arr)
      dupe_existing_tag = existing_tag_list.detect { |existing_tag| normalize_tag(existing_tag).downcase == normalized_tag.downcase }
      if dupe_existing_tag
        raise "An existing tag (#{dupe_existing_tag}) is the same, consider using update_tag?"
      end

      return normalized_tag
    end

    #Ensure that an administrative tag meets the proper mininum format
    #
    #@param tag_str [String] the tag
    #
    #@return [Array] the tag split into an array via ':'
    def validate_tag_format(tag_str)
      tag_arr = split_tag_to_arr(tag_str)

      if tag_arr.length < 2
        raise ArgumentError, "Invalid tag structure: tag '#{tag_str}' must have at least 2 elements"
      end

      if tag_arr.detect {|str| str.empty?}
        raise ArgumentError, "Invalid tag structure: tag '#{tag_str}' contains empty elements"
      end
      return tag_arr
    end

    #Add an administrative tag to an item, you will need to seperately save the item to write it to fedora
    #
    #param tag [string] The tag you wish to add
    def add_tag(tag)
        identity_metadata_ds = self.identityMetadata
        normalized_tag = validate_and_normalize_tag(tag, identity_metadata_ds.tags)
        identity_metadata_ds.add_value(:tag, normalized_tag)
    end

    def remove_tag(tag)
      removed = false
      self.identityMetadata.ng_xml.search('//tag').each do |node|
        if normalize_tag(node.content) === normalize_tag(tag)
          node.remove
          removed = true
        end
      end
      return removed
    end

    def update_tag(old_tag, new_tag)
      updated = false
      self.identityMetadata.ng_xml.search('//tag').each do |node|
        if normalize_tag(node.content) == normalize_tag(old_tag)
          node.content = normalize_tag(new_tag)
          updated = true
        end
      end
      return updated
    end

    def get_related_obj_display_title(related_obj, default_title)
      if related_obj
        if related_obj.datastreams["DC"] && related_obj.datastreams["DC"].title
          return related_obj.datastreams["DC"].title
        else
          return related_obj.label
        end
      end

      return default_title
    end


    private
    def solrize_related_obj_titles(solr_doc, relationships, title_hash, hydrus_title_hash, field_name, hydrus_field_name)
      title_type = :symbol  # we'll get an _ssim because of the type
      title_attrs = [:stored_searchable]  # we'll also get a _tesim from this attr
      relationships.each do |rel_node|
        rel_druid = rel_node['rdf:resource']
        next unless rel_druid   # TODO: warning here would also be useful
        rel_druid = rel_druid.gsub('info:fedora/', '')
        if title_hash.has_key?(rel_druid) || hydrus_title_hash.has_key?(rel_druid)
          add_solr_value(solr_doc, hydrus_field_name, hydrus_title_hash[rel_druid], title_type, title_attrs) if hydrus_title_hash.has_key? rel_druid
          add_solr_value(solr_doc, field_name, title_hash[rel_druid], title_type, title_attrs) if title_hash.has_key? rel_druid
        else
          related_obj = Dor.find(rel_druid)
          related_obj_title = get_related_obj_display_title(related_obj, rel_druid)
          if related_obj && related_obj.tags.include?('Project : Hydrus')
            add_solr_value(solr_doc, hydrus_field_name, related_obj_title, title_type, title_attrs)
            hydrus_title_hash[rel_druid] = related_obj_title
          else
            add_solr_value(solr_doc, field_name, related_obj_title, title_type, title_attrs)
            title_hash[rel_druid] = related_obj_title
          end
        end
      end
    end
  end
end
