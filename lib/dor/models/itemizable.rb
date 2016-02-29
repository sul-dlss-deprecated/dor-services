require 'fileutils'
require 'uri'

module Dor
  module Itemizable
    extend ActiveSupport::Concern

    included do
      has_metadata :name => 'contentMetadata', :type => Dor::ContentMetadataDS, :label => 'Content Metadata', :control_group => 'M'
    end

    DIFF_FILENAME = 'cm_inv_diff'

    # Deletes all cm_inv_diff files in the workspace for the Item
    def clear_diff_cache
      if Dor::Config.stacks.local_workspace_root.nil?
        raise ArgumentError, 'Missing Dor::Config.stacks.local_workspace_root'
      end
      druid = DruidTools::Druid.new(pid, Dor::Config.stacks.local_workspace_root)
      diff_pattern = File.join(druid.temp_dir, DIFF_FILENAME + '.*')
      FileUtils.rm_f Dir.glob(diff_pattern)
    end

    # Retrieves file difference manifest for contentMetadata from SDR
    #
    # @param [String] subset keyword for file attributes :shelve, :preserve, :publish. Default is :all.
    # @param [String] version
    # @return [String] XML contents of cm_inv_diff manifest
    def get_content_diff(subset = :all, version = nil)
      if Dor::Config.stacks.local_workspace_root.nil?
        raise Dor::ParameterError, 'Missing Dor::Config.stacks.local_workspace_root'
      end

      current_content = datastreams['contentMetadata'].content
      if current_content.nil?
        raise Dor::Exception, 'Missing contentMetadata datastream'
      end

      Sdr::Client.get_content_diff(druid, current_content, subset, version)
    end
  end
end
