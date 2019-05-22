# frozen_string_literal: true

module Dor
  class StaticConfig
    # Represents the configuration for the Dor::CleanupService
    class CleanupConfig
      def initialize(hash)
        @local_workspace_root = hash.fetch(:local_workspace_root)
      end

      def local_export_home(new_value = nil)
        @local_export_home = new_value if new_value
        @local_export_home
      end

      def local_workspace_root(new_value = nil)
        @local_workspace_root = new_value if new_value
        @local_workspace_root
      end

      def local_assembly_root(new_value = nil)
        @local_assembly_root = new_value if new_value
        @local_assembly_root
      end
    end
  end
end
