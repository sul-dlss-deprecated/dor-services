# frozen_string_literal: true

module Dor
  module Identifiable
    extend ActiveSupport::Concern

    # ids for previous and current catkeys
    CATKEY_TYPE_ID = 'catkey'
    PREVIOUS_CATKEY_TYPE_ID = 'previous_catkey'

    included do
      has_metadata name: 'DC', type: SimpleDublinCoreDs, label: 'Dublin Core Record for self object'
      has_metadata name: 'identityMetadata', type: Dor::IdentityMetadataDS, label: 'Identity Metadata'
    end

    module ClassMethods
      attr_reader :object_type
      def has_object_type(str)
        @object_type = str
        Dor.registered_classes[str] = self
      end

      # Overrides the method in ActiveFedora to mint a pid using SURI rather
      # than the default Fedora sequence
      def assign_pid(_obj)
        return Dor::SuriService.mint_id if Dor::Config.suri.mint_ids

        super
      end
    end

    # helper method to get the tags as an array
    def tags
      identityMetadata.tag
    end

    # helper method to get just the content type tag
    def content_type_tag
      content_tag = tags.select { |tag| tag.include?('Process : Content Type') }
      content_tag.size == 1 ? content_tag[0].split(':').last.strip : ''
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
    alias set_source_id source_id=
    deprecate set_source_id: 'Use source_id= instead'

    # Convenience method to get the current catkey
    # @return [String] current catkey value (or nil if none found)
    def catkey
      identityMetadata.otherId(CATKEY_TYPE_ID).first
    end

    # Convenience method to set the catkey
    # @param  [String] catkey the new source identifier
    # @return [String] same value, as per Ruby assignment convention
    def catkey=(val)
      # if there was already a catkey in the record, store that in the "previous" spot (assuming there is no change)
      identityMetadata.add_otherId("#{PREVIOUS_CATKEY_TYPE_ID}:#{catkey}") if val != catkey && !catkey.blank?

      if val.blank? # if we are setting the catkey to blank, remove the node from XML
        remove_other_Id(CATKEY_TYPE_ID)
      elsif catkey.blank? # if there is no current catkey, then add it
        add_other_Id(CATKEY_TYPE_ID, val)
      else # if there is a current catkey, update the current catkey to the new value
        update_other_Id(CATKEY_TYPE_ID, val)
      end

      val
    end

    # Convenience method to get the previous catkeys (will be an array)
    # @return [Array] previous catkey values (empty array if none found)
    def previous_catkeys
      identityMetadata.otherId(PREVIOUS_CATKEY_TYPE_ID)
    end

    def add_other_Id(type, val)
      raise 'There is an existing entry for ' + type + ', consider using update_other_Id().' if identityMetadata.otherId(type).length > 0

      identityMetadata.add_otherId(type + ':' + val)
    end

    def update_other_Id(type, new_val, val = nil)
      identityMetadata.ng_xml.search('//otherId[@name=\'' + type + '\']')
                      .select { |node| val.nil? || node.content == val }
                      .each { identityMetadata.ng_xml_will_change! }
                      .each { |node| node.content = new_val }
                      .any?
    end

    def remove_other_Id(type, val = nil)
      identityMetadata.ng_xml.search('//otherId[@name=\'' + type + '\']')
                      .select { |node| val.nil? || node.content == val }
                      .each { identityMetadata.ng_xml_will_change! }
                      .each(&:remove)
                      .any?
    end

    # turns a tag string into an array with one element per tag part.
    # split on ":", disregard leading and trailing whitespace on tokens.
    def split_tag_to_arr(tag_str)
      tag_str.split(':').map(&:strip)
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
      raise "An existing tag (#{dupe_existing_tag}) is the same, consider using update_tag?" if dupe_existing_tag

      normalized_tag
    end

    # Ensure that an administrative tag meets the proper mininum format
    # @param tag_str [String] the tag
    # @return [Array] the tag split into an array via ':'
    def validate_tag_format(tag_str)
      tag_arr = split_tag_to_arr(tag_str)
      raise ArgumentError, "Invalid tag structure: tag '#{tag_str}' must have at least 2 elements" if tag_arr.length < 2
      raise ArgumentError, "Invalid tag structure: tag '#{tag_str}' contains empty elements" if tag_arr.detect(&:empty?)

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
                      .each { identityMetadata.ng_xml_will_change! }
                      .each(&:remove)
                      .any?
    end

    def update_tag(old_tag, new_tag)
      normtag = normalize_tag(old_tag)
      identityMetadata.ng_xml.search('//tag')
                      .select { |node| normalize_tag(node.content) == normtag }
                      .each { identityMetadata.ng_xml_will_change! }
                      .each { |node| node.content = normalize_tag(new_tag) }
                      .any?
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
    def remove_druid_prefix(druid = id)
      result = druid.match(/#{pid_regex}/)
      result.nil? ? druid : result[0] # if no matches, return the string passed in, otherwise return the match
    end

    # Override ActiveFedora::Core#adapt_to_cmodel (used with associations, among other places) to
    # preferentially use the objectType asserted in the identityMetadata.
    def adapt_to_cmodel
      object_type = identityMetadata.objectType.first
      object_class = Dor.registered_classes[object_type]

      if object_class
        instance_of?(object_class) ? self : adapt_to(object_class)
      else
        if ActiveFedora::VERSION < '8'
          result = super
          if result.class == Dor::Abstract
            adapt_to(Dor::Item)
          else
            result
          end
        else
          begin
            super
          rescue ActiveFedora::ModelNotAsserted
            adapt_to(Dor::Item)
          end
        end
      end
    end
  end
end
