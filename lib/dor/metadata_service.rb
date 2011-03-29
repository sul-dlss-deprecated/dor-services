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
      
      def register(handler_class)
        ['fetch', 'label', 'prefixes'].each do |method|
          unless handler_class.instance_methods.include?(method)
            raise TypeError, "Metadata handlers must define ##{method.to_s}"
          end
        end
        handler = handler_class.new
        handler.prefixes.each do |prefix|
          handlers[prefix.to_sym] = handler
        end
        return handler
      end
      
      def known_prefixes
        return handlers.keys
      end
      
      def fetch(identifier)
        (prefix, identifier) = identifier.split(/:/,2)
        handler = handler_for(prefix)
        handler.fetch(prefix, identifier)
      end

      def label_for(identifier)
        (prefix, identifier) = identifier.split(/:/,2)
        handler = handler_for(prefix)
        handler.label(handler.fetch(prefix, identifier))
      end
      
      def handler_for(prefix)
        handler = handlers[prefix.to_sym]
        if handler.nil?
          raise MetadataError, "Unkown metadata prefix: #{prefix}"
        end
        return handler
      end
      
      private
      def handlers
        @handlers ||= {}
      end
      
    end
    
  end
  
end

Dir[File.join(File.dirname(__FILE__),'metadata_handlers','*.rb')].each { |handler_file|
  load handler_file
}
