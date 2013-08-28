require 'fileutils'
require 'uri'

module Dor
  module Itemizable
    extend ActiveSupport::Concern

    included do
      has_metadata :name => "contentMetadata", :type => Dor::ContentMetadataDS, :label => 'Content Metadata', :control_group => 'M'
    end
    
    DIFF_FILENAME = 'cm_inv_diff'

    # Deletes all cm_inv_diff files in the workspace for the Item
    def clear_diff_cache
      if Dor::Config.stacks.local_workspace_root.nil?
        raise ArgumentError, 'Missing Dor::Config.stacks.local_workspace_root' 
      end
      druid = DruidTools::Druid.new(self.pid, Dor::Config.stacks.local_workspace_root)
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
      unless %w{all shelve preserve publish}.include?(subset.to_s)
        raise Dor::ParameterError, "Invalid subset value: #{subset}"
      end

      basename = version.nil? ? "#{DIFF_FILENAME}.#{subset}.xml" : "#{DIFF_FILENAME}.#{subset}.#{version}.xml"
      druid = DruidTools::Druid.new(self.pid, Dor::Config.stacks.local_workspace_root)
      diff_cache = File.join(druid.temp_dir, basename)
      # check for cached copy before contacting SDR
      if File.exists? diff_cache
        File.read(diff_cache)
      else
        # fetch content metadata inventory difference from SDR
        if Dor::Config.sdr.rest_client.nil?
          raise Dor::ParameterError, 'Missing Dor::Config.sdr.rest_client'
        end
        sdr_client = Dor::Config.sdr.rest_client
        current_content = self.datastreams['contentMetadata'].content
        if current_content.nil?
          raise Dor::Exception, "Missing contentMetadata datastream"
        end
        query_string = { :subset => subset.to_s }
        query_string[:version] = version.to_s unless version.nil?
        query_string = URI.encode_www_form(query_string)
        sdr_query = "objects/#{self.pid}/#{DIFF_FILENAME}?#{query_string}"
        response = sdr_client[sdr_query].post(current_content, :content_type => 'application/xml')
        # cache response
        File.open(diff_cache, 'w') { |f| f << response }
        response
      end
    end
    
  end
end