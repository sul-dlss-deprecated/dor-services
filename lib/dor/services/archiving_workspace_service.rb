module Dor

  # Rename the druid trees  at the end of the accessionWF in order to be cleaned/deleted later.
  class ArchivingWorkspaceService

    def self.archive_workspace_druid_tree(druid, workspace_root)
      druid_tree_path = DruidTools::Druid.new(druid, workspace_root).pathname.to_s
      FileUtils.mv(druid_tree_path, druid_tree_path+"_v2")
    end
    
  end
end