# frozen_string_literal: true

module Dor
  module Identifiable
    extend ActiveSupport::Concern

    # ids for previous and current catkeys
    CATKEY_TYPE_ID = 'catkey'
    PREVIOUS_CATKEY_TYPE_ID = 'previous_catkey'

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

    # Convenience method to get the current catkey
    # @return [String] current catkey value (or nil if none found)
    def catkey
      identityMetadata.otherId(CATKEY_TYPE_ID).first
    end

    # Convenience method to set the catkey
    # @param  [String] val the new source identifier
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
  end
end
