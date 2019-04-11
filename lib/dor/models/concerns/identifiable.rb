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
