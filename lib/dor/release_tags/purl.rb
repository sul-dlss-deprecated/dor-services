# frozen_string_literal: true

module Dor
  module ReleaseTags
    class Purl
      # Determine projects in which an item is released
      # @param [String] pid identifier of the item to get the release tags for
      def initialize(pid:, purl_host:)
        @pid = pid
        @purl_host = purl_host
      end

      # This function calls purl and gets a list of all release tags currently in purl.  It then compares to the list you have generated.
      # Any tag that is on purl, but not in the newly generated list is added to the new list with a value of false.
      # @param new_tags [Hash{String => Boolean}] all new tags in the form of !{"Project" => Boolean}
      # @return [Hash{String => Boolean}] all namespaces, keys are Project name Strings, values are Boolean
      def released_for(new_tags)
        missing_tags = release_tags_from_purl.map(&:downcase) - new_tags.keys.map(&:downcase)
        missing_tags.each do |missing_tag|
          new_tags[missing_tag.capitalize] = { 'release' => false }
        end
        new_tags
      end

      private

      # Pull all release nodes from the public xml obtained via the purl query
      # @param doc [Nokogiri::HTML::Document] The druid of the object you want
      # @return [Array] An array containing all the release tags
      def release_tags_from_purl_xml(doc)
        nodes = doc.xpath('//publicObject/releaseData').children
        # We only want the nodes with a name that isn't text
        nodes.reject { |n| n.name.nil? || n.name.casecmp('text') == 0 }.map { |n| n.attr('to') }.uniq
      end

      # Pull all release nodes from the public xml obtained via the purl query
      # @return [Array] An array containing all the release tags
      def release_tags_from_purl
        release_tags_from_purl_xml(purl_client.fetch)
      end

      def purl_client
        PurlClient.new(host: @purl_host,
                       pid: pid)
      end

      attr_reader :pid
    end
  end
end
