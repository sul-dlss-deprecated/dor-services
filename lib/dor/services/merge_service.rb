# frozen_string_literal: true

module Dor
  class MergeService
    extend Deprecation
    self.deprecation_horizon = 'dor-services version 7.0.0'

    class << self
      def self.merge_into_primary(primary_druid, secondary_druids, tag, logger = nil)
        # TODO: test the secondary_obj to see if we've processed it already
        merge_service = Dor::MergeService.new primary_druid, secondary_druids, tag, logger
        merge_service.check_objects_editable
        merge_service.move_metadata_and_content
        merge_service.decommission_secondaries
        # kick off commonAccessioning for the primary?
      end
      deprecation_deprecate merge_into_primary: 'No longer used by any DLSS code'
    end

    def initialize(primary_druid, secondary_pids, tag, logger = nil)
      @primary = Dor.find primary_druid
      @secondary_pids = secondary_pids
      @secondary_objs = secondary_pids.map { |pid| Dor.find pid }
      if logger.nil?
        @logger = Logger.new(STDERR)
      else
        @logger = logger
      end
      @tag = tag
    end

    def check_objects_editable
      raise Dor::Exception, "Primary object is not editable: #{@primary.pid}" unless @primary.allows_modification?

      non_editable = @secondary_objs.detect { |obj| !obj.allows_modification? }
      raise Dor::Exception, "Secondary object is not editable: #{non_editable.pid}" if non_editable
    end
    deprecation_deprecate check_objects_editable: 'No longer used by any DLSS code'

    def move_metadata_and_content
      FileMetadataMergeService.copy_file_resources @primary, @secondary_pids
      @primary.save
      copy_workspace_content
    end
    deprecation_deprecate move_metadata_and_content: 'No longer used by any DLSS code'

    # Copies the content from the secondary object workspace to the primary object's workspace
    #   Depends on Dor::Config.stacks.local_workspace_root
    def copy_workspace_content
      pri_file = @primary.contentMetadata.resource(0).file(0).id.first
      pri_druid = DruidTools::Druid.new @primary.pid, Dor::Config.stacks.local_workspace_root
      dest_path = pri_druid.find_filelist_parent 'content', pri_file
      primary_cm = @primary.contentMetadata.ng_xml

      @secondary_objs.each do |secondary|
        sec_druid = DruidTools::Druid.new secondary.pid, Dor::Config.stacks.local_workspace_root
        secondary.contentMetadata.ng_xml.xpath('//resource').each do |src_resource|
          primary_resource = primary_cm.at_xpath "//resource[attr[@name = 'mergedFromPid']/text() = '#{secondary.pid}' and
                                                             attr[@name = 'mergedFromResource']/text() = '#{src_resource['id']}' ]"
          sequence = primary_resource['sequence']
          src_resource.xpath('//file/@id').map(&:value).each do |file_id|
            copy_path = sec_druid.find_content file_id
            new_name = SecondaryFileNameService.create(file_id, sequence)
            # TODO: verify new_name exists in primary_cm?
            FileUtils.cp(copy_path, File.join(dest_path, "/#{new_name}"))
          end
        end
      end
    end
    deprecation_deprecate copy_workspace_content: 'No longer used by any DLSS code'

    def decommission_secondaries
      @secondary_objs.each do |secondary_obj|
        begin
          @current_secondary = secondary_obj
          @current_secondary.decommission @tag
          @current_secondary.save

          unshelve
          unpublish
          Dor::CleanupService.cleanup_by_druid @current_secondary.pid
          Dor::Config.workflow.client.archive_active_workflow 'dor', @current_secondary.pid
        rescue StandardError => e
          @logger.error "Unable to decommission #{@current_secondary.pid} with primary object #{@primary.pid}: #{e.inspect}"
          @logger.error e.backtrace.join("\n")
        end
      end
    end
    deprecation_deprecate decommission_secondaries: 'No longer used by any DLSS code'

    alias decomission_secondaries decommission_secondaries
    deprecate decomission_secondaries: 'Use decommission_secondaries instead'

    # Remove content from stacks
    # TODO: might set workflow status in future for robot to do
    def unshelve
      DigitalStacksService.prune_stacks_dir @current_secondary.pid
    end
    deprecation_deprecate unshelve: 'No longer used by any DLSS code'

    # Withdraw item from Purl
    # TODO: might set workflow status in future for robot to do
    def unpublish
      @current_secondary.publish_metadata
    end
    deprecation_deprecate unpublish: 'No longer used by any DLSS code'
  end
end
