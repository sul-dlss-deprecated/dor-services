module Dor

  class MergeService

    def MergeService.merge_into_primary druids, logger = nil
      primary_druid = druids.shift
      primary_obj = Dor::Item.find primary_druid

      druids.each do |secondary_druid|
        begin
          # TODO test the secondary_obj to see if we've processed it already
          secondary_obj = Dor::Item.find secondary_druid
          merge_service = Dor::MergeService.new primary_obj, secondary_obj

          primary_obj.copy_file_resources secondary_obj, logger
          merge_service.copy_workspace_content

          secondary_obj.decomission
          secondary_obj.save
          primary_obj.save

          merge_service.unshelve
          merge_service.unpublish
          Dor::CleanupService.cleanup_by_druid secondary_obj.pid
        rescue => e
          logger.error "Unable to merge #{secondary_druid} into #{primary_druid}: #{e.inspect}" if logger
          logger.error e.backtrace.join("\n") if logger
        end
      end
    end

    def initialize primary, secondary
      @primary = primary
      @secondary = secondary
    end

    # Copies the content from the secondary object workspace to the primary object's workspace
    #   Depends on Dor::Config.stacks.local_workspace_root
    def copy_workspace_content
      pri_file = @primary.contentMetadata.resource(0).file(0).id.first
      pri_druid = DruidTools::Druid.new @primary.pid, Dor::Config.stacks.local_workspace_root
      dest_path = pri_druid.find_filelist_parent 'content', pri_file

      sec_druid = DruidTools::Druid.new @secondary.pid, Dor::Config.stacks.local_workspace_root
      @secondary.contentMetadata.ng_xml.xpath("//file/@id").map {|id| id.value }.each do |file_id|
        copy_path = sec_druid.find_content file_id
        FileUtils.cp copy_path, dest_path
      end

    end

    # remove content from stacks
    # TODO might set workflow status in future for robot to do
    def unshelve
      DigitalStacksService.remove_stacks_dir @secondary.pid
    end

    # Push the new metadata to purl
    # TODO might set workflow status in future for robot to do
    def unpublish
      @primary.publish_metadata
    end
  end
end
