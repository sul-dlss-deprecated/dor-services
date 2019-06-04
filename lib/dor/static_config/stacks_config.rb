# frozen_string_literal: true

module Dor
  class StaticConfig
    # Represents the configuration for the shared filesystem direcotories
    class StacksConfig
      def initialize(hash)
        @document_cache_host = hash.fetch(:document_cache_host)
        @local_stacks_root = hash.fetch(:local_stacks_root)
        @local_workspace_root = hash.fetch(:local_workspace_root)
        @local_document_cache_root = hash.fetch(:local_document_cache_root)
      end

      def configure(&block)
        instance_eval(&block)
      end

      def document_cache_host(new_value = nil)
        @document_cache_host = new_value if new_value
        @document_cache_host
      end

      def local_stacks_root(new_value = nil)
        @local_stacks_root = new_value if new_value
        @local_stacks_root
      end

      def local_workspace_root(new_value = nil)
        @local_workspace_root = new_value if new_value
        @local_workspace_root
      end

      def local_document_cache_root(new_value = nil)
        @local_document_cache_root = new_value if new_value
        @local_document_cache_root
      end
    end
  end
end
