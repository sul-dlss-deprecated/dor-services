# frozen_string_literal: true

module Dor
  # Manage tags on an object
  class TagService
    def self.add(item, tag)
      new(item).add(tag)
    end

    def self.remove(item, tag)
      new(item).remove(tag)
    end

    def self.update(item, old_tag, new_tag)
      new(item).update(old_tag, new_tag)
    end

    def initialize(item)
      @item = item
    end

    # Add an administrative tag to an item, you will need to seperately save the item to write it to fedora
    # @param tag [string] The tag you wish to add
    def add(tag)
      normalized_tag = validate_and_normalize_tag(tag, identity_metadata.tags)
      identity_metadata.add_value(:tag, normalized_tag)
    end

    def remove(tag)
      normtag = normalize_tag(tag)
      tag_nodes
        .select { |node| normalize_tag(node.content) == normtag }
        .each { identity_metadata.ng_xml_will_change! }
        .each(&:remove)
        .any?
    end

    def update(old_tag, new_tag)
      normtag = normalize_tag(old_tag)
      tag_nodes
        .select { |node| normalize_tag(node.content) == normtag }
        .each { identity_metadata.ng_xml_will_change! }
        .each { |node| node.content = normalize_tag(new_tag) }
        .any?
    end

    private

    attr_reader :item
    def identity_metadata
      item.identityMetadata
    end

    def tag_nodes
      identity_metadata.ng_xml.search('//tag')
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
  end
end
