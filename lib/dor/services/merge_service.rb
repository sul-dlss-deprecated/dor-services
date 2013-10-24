module Dor

  class MergeService

    def MergeService.merge_into_primary primary_druid, secondary_druids, logger = nil
      # TODO test the secondary_obj to see if we've processed it already
      merge_service = Dor::MergeService.new primary_druid, secondary_druids, logger
      merge_service.check_objects_editable
      merge_service.move_metadata_and_content
      merge_service.decomission_secondaries
      # kick off commonAccessioning for the primary?
    end

    def initialize primary_druid, secondary_pids, logger = nil
      @primary = Dor::Item.find primary_druid
      @secondary_pids = secondary_pids
      @secondary_objs = secondary_pids.map {|pid|  Dor::Item.find pid }
      if logger.nil?
        @logger = Logger.new(STDERR)
      else
        @logger = logger
      end
    end

    def check_objects_editable
      unless @primary.allows_modification?
        raise Dor::Exception.new "Primary object is not editable: #{@primary.pid}"
      end
      if ( non_editable = (@secondary_objs.detect? {|obj| ! obj.allows_modification? } ))
        raise Dor::Exception.new "Secondary object is not editable: #{non_editable.pid}"
      end
    end

    def move_metadata_and_content
      @primary.copy_file_resources secondary_druids, @logger
      @primary.save
      copy_workspace_content
    end

    # Copies the content from the secondary object workspace to the primary object's workspace
    #   Depends on Dor::Config.stacks.local_workspace_root
    def copy_workspace_content
      pri_file = @primary.contentMetadata.resource(0).file(0).id.first
      pri_druid = DruidTools::Druid.new @primary.pid, Dor::Config.stacks.local_workspace_root
      dest_path = pri_druid.find_filelist_parent 'content', pri_file

      @secondary_objs.each do |secondary|
        sec_druid = DruidTools::Druid.new secondary.pid, Dor::Config.stacks.local_workspace_root
        secondary.contentMetadata.ng_xml.xpath("//file/@id").map {|id| id.value }.each do |file_id|
          copy_path = sec_druid.find_content file_id
          FileUtils.cp copy_path, dest_path
        end
      end
    end

    def decomission_secondaries
      @secondary_objs.each do |secondary_obj|
        begin
          @current_secondary = secondary_obj
          @current_secondary.decomission
          @current_secondary.save

          unshelve
          unpublish
          Dor::CleanupService.cleanup_by_druid @current_secondary.pid
        rescue => e
          @logger.error "Unable to decomission #{@current_secondary.pid} with primary object #{@primary.pid}: #{e.inspect}"
          @logger.error e.backtrace.join("\n")
        end
      end
    end

    # remove content from stacks
    # TODO might set workflow status in future for robot to do
    def unshelve
      DigitalStacksService.remove_stacks_dir @current_secondary.pid
    end

    # Push altered metadata to purl
    # TODO might set workflow status in future for robot to do
    def unpublish
      @current_secondary.publish_metadata
    end
  end
end
