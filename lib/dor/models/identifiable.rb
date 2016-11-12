module Dor
  module Identifiable
    extend ActiveSupport::Concern
    include SolrDocHelper
    include Eventable
    include Upgradable

    included do
      has_metadata :name => 'DC', :type => SimpleDublinCoreDs, :label => 'Dublin Core Record for self object'
      has_metadata :name => 'identityMetadata', :type => Dor::IdentityMetadataDS, :label => 'Identity Metadata'
    end

    module ClassMethods
      attr_reader :object_type
      def has_object_type(str)
        @object_type = str
        Dor.registered_classes[str] = self
      end
    end

    def initialize(attrs = {})
      if Dor::Config.suri.mint_ids && !attrs[:pid]
        attrs = attrs.merge!({:pid => Dor::SuriService.mint_id, :new_object => true})
      end
      super
    end

    # helper method to get the tags as an array
    def tags
      identityMetadata.tag
    end

    # helper method to get just the content type tag
    def content_type_tag
      content_tag = tags.select {|tag| tag.include?('Process : Content Type')}
      content_tag.size == 1 ? content_tag[0].split(':').last.strip : ''
    end

    ## Module-level variables, shared between ALL mixin includers (and ALL *their* includers/extenders)!
    ## used for caching found values
    @@collection_hash = {}
    @@apo_hash = {}

    def to_solr(solr_doc = {}, *args)
      assert_content_model
      solr_doc = super(solr_doc, *args)

      solr_doc[Dor::INDEX_VERSION_FIELD] = Dor::VERSION
      solr_doc['indexed_at_dtsi'] = Time.now.utc.xmlschema
      datastreams.values.each do |ds|
        add_solr_value(solr_doc, 'ds_specs', ds.datastream_spec_string, :string, [:symbol]) unless ds.new?
      end

      add_solr_value(solr_doc, 'title_sort', label, :string, [:stored_sortable])

      rels_doc = Nokogiri::XML(datastreams['RELS-EXT'].content)
      ns_hash = {'hydra' => 'http://projecthydra.org/ns/relations#', 'fedora' => 'info:fedora/fedora-system:def/relations-external#', 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'}
      apos = rels_doc.search('//rdf:RDF/rdf:Description/hydra:isGovernedBy', ns_hash)
      collections = rels_doc.search('//rdf:RDF/rdf:Description/fedora:isMemberOfCollection', ns_hash)
      solrize_related_obj_titles(solr_doc, apos, @@apo_hash, 'apo_title', 'nonhydrus_apo_title', 'hydrus_apo_title')
      solrize_related_obj_titles(solr_doc, collections, @@collection_hash, 'collection_title', 'nonhydrus_collection_title', 'hydrus_collection_title')

      solr_doc['metadata_source_ssi'] = identity_metadata_source
      solr_doc
    end

    # @return [String] calculated value for Solr index
    def identity_metadata_source
      if identityMetadata.otherId('catkey').first ||
         identityMetadata.otherId('barcode').first
        'Symphony'
      elsif identityMetadata.otherId('mdtoolkit').first
        'Metadata Toolkit'
      else
        'DOR'
      end
    end

    # Convenience method
    def source_id
      identityMetadata.sourceId
    end

    # Convenience method
    # @param  [String] source_id the new source identifier
    # @return [String] same value, as per Ruby assignment convention
    # @raise  [ArgumentError] see IdentityMetadataDS for logic
    def source_id=(source_id)
      identityMetadata.sourceId = source_id
    end
    alias_method :set_source_id, :source_id=
    deprecate set_source_id: 'Use source_id= instead'

    def add_other_Id(type, val)
      if identityMetadata.otherId(type).length > 0
        raise 'There is an existing entry for ' + type + ', consider using update_other_Id().'
      end
      identityMetadata.add_otherId(type + ':' + val)
    end

    def update_other_Id(type, new_val, val = nil)
      identityMetadata.ng_xml.search('//otherId[@name=\'' + type + '\']')
        .select { |node| val.nil? || node.content == val }
        .each  { |node| node.content = new_val }
        .any?
    end

    def remove_other_Id(type, val = nil)
      identityMetadata.ng_xml.search('//otherId[@name=\'' + type + '\']')
        .select { |node| val.nil? || node.content == val }
        .each(&:remove)
        .any?
    end

    # turns a tag string into an array with one element per tag part.
    # split on ":", disregard leading and trailing whitespace on tokens.
    def split_tag_to_arr(tag_str)
      tag_str.split(':').map {|str| str.strip}
    end

    # turn a tag array back into a tag string with a standard format
    def normalize_tag_arr(tag_arr)
      tag_arr.join(' : ')
    end

    # take a tag string and return a normalized tag string
    def normalize_tag(tag_str)
      normalize_tag_arr(split_tag_to_arr(tag_str))
    end

    # take a proposed tag string and a list of the existing tags for the object being edited.  if
    # the proposed tag is valid, return it in normalized form.  if not, raise an exception with an
    # explanatory message.
    def validate_and_normalize_tag(tag_str, existing_tag_list)
      tag_arr = validate_tag_format(tag_str)

      # note that the comparison for duplicate tags is case-insensitive, but we don't change case as part of the normalized version
      # we return, because we want to preserve the user's intended case.
      normalized_tag = normalize_tag_arr(tag_arr)
      dupe_existing_tag = existing_tag_list.detect { |existing_tag| normalize_tag(existing_tag).casecmp(normalized_tag) == 0 }
      if dupe_existing_tag
        raise "An existing tag (#{dupe_existing_tag}) is the same, consider using update_tag?"
      end
      normalized_tag
    end

    # Ensure that an administrative tag meets the proper mininum format
    # @param tag_str [String] the tag
    # @return [Array] the tag split into an array via ':'
    def validate_tag_format(tag_str)
      tag_arr = split_tag_to_arr(tag_str)
      if tag_arr.length < 2
        raise ArgumentError, "Invalid tag structure: tag '#{tag_str}' must have at least 2 elements"
      end
      if tag_arr.detect {|str| str.empty?}
        raise ArgumentError, "Invalid tag structure: tag '#{tag_str}' contains empty elements"
      end
      tag_arr
    end

    # Add an administrative tag to an item, you will need to seperately save the item to write it to fedora
    # @param tag [string] The tag you wish to add
    def add_tag(tag)
      identity_metadata_ds = identityMetadata
      normalized_tag = validate_and_normalize_tag(tag, identity_metadata_ds.tags)
      identity_metadata_ds.add_value(:tag, normalized_tag)
    end

    def remove_tag(tag)
      normtag = normalize_tag(tag)
      identityMetadata.ng_xml.search('//tag')
        .select { |node| normalize_tag(node.content) == normtag }
        .each(&:remove)
        .any?
    end

    def update_tag(old_tag, new_tag)
      normtag = normalize_tag(old_tag)
      identityMetadata.ng_xml.search('//tag')
        .select { |node| normalize_tag(node.content) == normtag }
        .each  { |node| node.content = normalize_tag(new_tag)  }
        .any?
    end

    def get_related_obj_display_title(related_obj, default_title)
      return default_title unless related_obj

      desc_md_ds = related_obj.datastreams['descMetadata']
      desc_md_ds_title = desc_md_ds ? desc_md_ds.title_info.main_title.first : nil
      desc_md_ds_title.present? ? desc_md_ds_title : default_title
    end

    # a regex that can be used to identify the last part of a druid (e.g. oo000oo0001)
    # @return [Regex] a regular expression to identify the ID part of the druid
    def pid_regex
      /[a-zA-Z]{2}[0-9]{3}[a-zA-Z]{2}[0-9]{4}/
    end

    # a regex that can be used to identify a full druid with prefix (e.g. druid:oo000oo0001)
    # @return [Regex] a regular expression to identify a full druid
    def druid_regex
      /druid:#{pid_regex}/
    end

    # Since purl does not use the druid: prefix but much of dor does, use this function to strip the druid: if needed
    # @return [String] the druid sans the druid: or if there was no druid: prefix, the entire string you passed
    def remove_druid_prefix(druid=id)
      result=druid.match(/#{pid_regex}/)
      result.nil? ? druid : result[0]  # if no matches, return the string passed in, otherwise return the match 
    end

    # Override ActiveFedora::Core#adapt_to_cmodel (used with associations, among other places) to
    # preferentially use the objectType asserted in the identityMetadata.
    def adapt_to_cmodel
      object_type = identityMetadata.objectType.first
      object_class = Dor.registered_classes[object_type]

      if object_class
        self.instance_of?(object_class) ? self : self.adapt_to(object_class)
      else
        if ActiveFedora::VERSION < '8'
          result = super
          if result.class == Dor::Abstract
            self.adapt_to(Dor::Item)
          else
            result
          end
        else
          begin
            super
          rescue ActiveFedora::ModelNotAsserted
            self.adapt_to(Dor::Item)
          end
        end
      end
    end

    private

    def solrize_related_obj_titles(solr_doc, relationships, title_hash, union_field_name, nonhydrus_field_name, hydrus_field_name)
      # TODO: if you wanted to get a little fancier, you could also solrize a 2 level hierarchy and display using hierarchial facets, like
      # ["SOURCE", "SOURCE : TITLE"] (e.g. ["Hydrus", "Hydrus : Special Collections"], see (exploded) tags in IdentityMetadataDS#to_solr).
      title_type = :symbol  # we'll get an _ssim because of the type
      title_attrs = [:stored_searchable]  # we'll also get a _tesim from this attr
      relationships.each do |rel_node|
        rel_druid = rel_node['rdf:resource']
        next unless rel_druid   # TODO: warning here would also be useful
        rel_druid = rel_druid.gsub('info:fedora/', '')

        # populate cache if necessary
        unless title_hash.key?(rel_druid)
          begin
            related_obj = Dor.find(rel_druid)
            related_obj_title = get_related_obj_display_title(related_obj, rel_druid)
            is_from_hydrus = (related_obj && related_obj.tags.include?('Project : Hydrus'))
            title_hash[rel_druid] = {'related_obj_title' => related_obj_title, 'is_from_hydrus' => is_from_hydrus}
          rescue ActiveFedora::ObjectNotFoundError
            # This may happen if the given APO or Collection does not exist (bad data)
            title_hash[rel_druid] = {'related_obj_title' => rel_druid, 'is_from_hydrus' => false}
          end
        end

        # cache should definitely be populated, so just use that to write solr field
        if title_hash[rel_druid]['is_from_hydrus']
          add_solr_value(solr_doc, hydrus_field_name, title_hash[rel_druid]['related_obj_title'], title_type, title_attrs)
        else
          add_solr_value(solr_doc, nonhydrus_field_name, title_hash[rel_druid]['related_obj_title'], title_type, title_attrs)
        end
        add_solr_value(solr_doc, union_field_name, title_hash[rel_druid]['related_obj_title'], title_type, title_attrs)
      end
    end
  end
end
