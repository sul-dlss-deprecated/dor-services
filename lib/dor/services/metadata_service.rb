require 'cache'

module Dor

  class MetadataError < Exception ; end

  #  class MetadataHandler
  #
  #    def fetch(prefix, identifier)
  #      ### Return metadata for prefix/identifier combo
  #    end
  #
  #    def label(metadata)
  #      ### Return a Fedora-compatible label from the metadata format returned by #fetch
  #    end
  #
  #  end

  class MetadataService

    class << self
      @@cache = Cache.new(nil, nil, 250, 300)

      def register(handler_class)
        %w(fetch label prefixes).each do |method|
          unless handler_class.instance_methods.include?(method) || handler_class.instance_methods.include?(method.to_sym)
            raise TypeError, "Metadata handlers must define ##{method}"
          end
        end
        handler = handler_class.new
        handler.prefixes.each do |prefix|
          handlers[prefix.to_sym] = handler
        end
        handler
      end

      def known_prefixes
        handlers.keys
      end

      def can_resolve?(identifier)
        (prefix, _identifier) = identifier.split(/:/, 2)
        handlers.keys.include?(prefix.to_sym)
      end

      # TODO: Return a prioritized list
      def resolvable(identifiers)
        identifiers.select { |identifier| self.can_resolve?(identifier) }
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
        raise MetadataError, "Unkown metadata prefix: #{prefix}" if handler.nil?
        handler
      end

      private
      def handlers
        @handlers ||= {}
      end

    end

  end

end

Dir[File.join(File.dirname(__FILE__), 'metadata_handlers', '*.rb')].each { |handler_file|
  load handler_file
}
