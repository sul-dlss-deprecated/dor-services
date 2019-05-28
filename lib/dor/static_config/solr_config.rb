# frozen_string_literal: true

module Dor
  class StaticConfig
    class SolrConfig
      # Represents the configuration for Solr
      def initialize(hash)
        @url = hash.fetch(:url)
      end

      def url(new_value = nil)
        @url = new_value if new_value
        @url
      end
    end
  end
end
