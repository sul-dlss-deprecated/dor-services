require 'pathname'

module Dor

  # Remove all traces of the object's data files from the workspace and export areas
  class CleanupService

    # @param [LyberCore::Robots::WorkItem] dor_item The DOR work item whose workspace should be cleaned up
    # @return [void] Delete all workspace and export entities for the druid
    def self.cleanup(dor_item)
      druid = dor_item.druid
      cleanup_by_druid druid
    end

    def self.cleanup_by_druid(druid)
      cleanup_workspace_content(druid, Config.cleanup.local_workspace_root)
      cleanup_workspace_content(druid, Config.cleanup.local_assembly_root)
      cleanup_export(druid)
    end

    # @param [String] druid The identifier for the object whose data is to be removed
    # @param [String] base The base directory to delete from
    # @return [void] remove the object's data files from the workspace area
    def self.cleanup_workspace_content(druid, base)
      DruidTools::Druid.new(druid, base).prune!
    end

    # @param [String] druid The identifier for the object whose data is to be removed
    # @return [void] remove copy of the data that was exported to preservation core
    def self.cleanup_export(druid)
      id = druid.split(':').last
      bag_dir = File.join(Config.cleanup.local_export_home, id)
      self.remove_branch(bag_dir)
      tarfile = "#{bag_dir}.tar"
      self.remove_branch(tarfile)
    end

    # @param [Pathname,String] pathname The full path of the branch to be removed
    # @return [void] Remove the specified directory and all its children
    def self.remove_branch(pathname)
      pathname = Pathname(pathname) if pathname.instance_of? String
      pathname.rmtree if pathname.exist?
    end

  end

end