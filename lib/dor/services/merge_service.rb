module Dor
  class MergeService

    def self.merge_into_primary(primary_druid, secondary_druids, tag, logger = nil)
      # TODO: test the secondary_obj to see if we've processed it already
      merge_service = Dor::MergeService.new primary_druid, secondary_druids, tag, logger
      merge_service.check_objects_editable
      merge_service.move_metadata_and_content
      merge_service.decomission_secondaries
      # kick off commonAccessioning for the primary?
    end

    def initialize(primary_druid, secondary_pids, tag, logger = nil)
      @primary = Dor.find primary_druid
      @secondary_pids = secondary_pids
      @secondary_objs = secondary_pids.map {|pid|  Dor.find pid }
      if logger.nil?
        @logger = Logger.new(STDERR)
      else
        @logger = logger
      end
      @tag = tag
    end

    def check_objects_editable
      raise Dor::Exception, "Primary object is not editable: #{@primary.pid}" unless @primary.allows_modification?
      non_editable = @secondary_objs.detect {|obj| !obj.allows_modification? }
      raise Dor::Exception, "Secondary object is not editable: #{non_editable.pid}" if non_editable
    end

    def move_metadata_and_content
      @primary.copy_file_resources @secondary_pids
      @primary.save
      copy_workspace_content
    end

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
          src_resource.xpath('//file/@id').map {|id| id.value }.each do |file_id|
            copy_path = sec_druid.find_content file_id
            new_name = secondary.new_secondary_file_name(file_id, sequence)
            # TODO: verify new_name exists in primary_cm?
            FileUtils.cp(copy_path, File.join(dest_path, "/#{new_name}"))
          end
        end
      end
    end

    def decomission_secondaries
      @secondary_objs.each do |secondary_obj|
        begin
          @current_secondary = secondary_obj
          @current_secondary.decomission @tag
          @current_secondary.save

          unshelve
          unpublish
          Dor::CleanupService.cleanup_by_druid @current_secondary.pid
          Dor::Config.workflow.client.archive_active_workflow 'dor', @current_secondary.pid
        rescue => e
          @logger.error "Unable to decomission #{@current_secondary.pid} with primary object #{@primary.pid}: #{e.inspect}"
          @logger.error e.backtrace.join("\n")
        end
      end
    end

    # Remove content from stacks
    # TODO: might set workflow status in future for robot to do
    def unshelve
      DigitalStacksService.prune_stacks_dir @current_secondary.pid
    end

    # Withdraw item from Purl
    # TODO: might set workflow status in future for robot to do
    def unpublish
      @current_secondary.publish_metadata
    end
  end
end
