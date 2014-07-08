module Dor

  # Rename the druid trees  at the end of the accessionWF in order to be cleaned/deleted later.
  class ArchiveWorkspaceService

    def self.archive_workspace_druid_tree(druid, version, workspace_root)
      
      druid_tree_path = DruidTools::Druid.new(druid, workspace_root).pathname.to_s
      
      raise "The archived directory #{druid_tree_path}_v#{version} already existed." if  File.exists?("#{druid_tree_path}_v#{version}") 
      
      if File.exists?(druid_tree_path) 
        FileUtils.mv(druid_tree_path, "#{druid_tree_path}_v#{version}")
      end #Else is a truncated tree where we shouldn't do anything

    end
    
  end
end