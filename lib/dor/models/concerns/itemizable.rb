# frozen_string_literal: true

require 'fileutils'
require 'uri'

module Dor
  module Itemizable
    extend ActiveSupport::Concern
    extend Deprecation
    self.deprecation_horizon = 'dor-services version 7.0.0'

    included do
      has_metadata name: 'contentMetadata', type: Dor::ContentMetadataDS, label: 'Content Metadata', control_group: 'M'
    end

    DIFF_FILENAME = 'cm_inv_diff'

    # Deletes all cm_inv_diff files in the workspace for the Item
    def clear_diff_cache
      raise ArgumentError, 'Missing Dor::Config.stacks.local_workspace_root' if Dor::Config.stacks.local_workspace_root.nil?

      druid = DruidTools::Druid.new(pid, Dor::Config.stacks.local_workspace_root)
      diff_pattern = File.join(druid.temp_dir, DIFF_FILENAME + '.*')
      FileUtils.rm_f Dir.glob(diff_pattern)
    end
    deprecation_deprecate clear_diff_cache: 'No longer used by any DLSS code and will be removed without replacement'

    # Retrieves file difference manifest for contentMetadata from SDR
    #
    # @param [Symbol] subset keyword for file attributes :shelve, :preserve, :publish. Default is :all.
    # @param [String] version
    # @return [Moab::FileInventoryDifference] XML contents of cm_inv_diff manifest
    def get_content_diff(subset = :all, version = nil)
      raise Dor::ParameterError, 'Missing Dor::Config.stacks.local_workspace_root' if Dor::Config.stacks.local_workspace_root.nil?

      raise Dor::Exception, 'Missing contentMetadata datastream' if !respond_to?(:contentMetadata) || contentMetadata.nil?

      Sdr::Client.get_content_diff(pid, contentMetadata.content, subset.to_s, version)
    end
    deprecation_deprecate get_content_diff: 'Use Sdr::Client.get_content_diff instead'
  end
end
