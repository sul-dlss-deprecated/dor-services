# frozen_string_literal: true

require 'cache'
require 'dor/services/metadata_handlers/catalog_handler'

module Dor
  class MetadataError < RuntimeError; end

  class MetadataService
    class << self
      @@cache = Cache.new(nil, nil, 250, 300)

      def known_prefixes
        handlers.keys
      end

      def can_resolve?(identifier)
        (prefix, _identifier) = identifier.split(/:/, 2)
        handlers.key?(prefix.to_sym)
      end

      # TODO: Return a prioritized list
      def resolvable(identifiers)
        identifiers.select { |identifier| can_resolve?(identifier) }
      end

      def fetch(identifier)
        @@cache.fetch(identifier) do
          (prefix, identifier) = identifier.split(/:/, 2)
          handler = handler_for(prefix)
          handler.fetch(prefix, identifier)
        end
      end

      def label_for(identifier)
        (prefix, identifier) = identifier.split(/:/, 2)
        handler = handler_for(prefix)
        handler.label(handler.fetch(prefix, identifier))
      end

      def handler_for(prefix)
        handler = handlers[prefix.to_sym]
        raise MetadataError, "Unknown metadata prefix: #{prefix}" if handler.nil?

        handler
      end

      private

      def handlers
        @handlers ||= {}.tap do |md_handlers|
          # There's only one. If additional handlers are added, will need to be registered here.
          register(CatalogHandler.new, md_handlers)
        end
      end

      def register(handler, md_handlers)
        handler.prefixes.each do |prefix|
          md_handlers[prefix.to_sym] = handler
        end
      end
    end
  end
end
