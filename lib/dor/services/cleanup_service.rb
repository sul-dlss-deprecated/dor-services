require 'pathname'

module Dor

  # Remove all traces of the object's data files from the workspace and export areas
  class CleanupService

    # @param dor_item [LyberCore::Robots::WorkItem] The DOR work item whose workspace should be cleaned up
    # @return [void] Delete all workspace and export entities for the druid
    def self.cleanup(dor_item)
      druid = dor_item.pid
      cleanup_workspace(druid)
      cleanup_export(druid)
    end

    # @param druid [String] The identifier for the object whose data is to be removed
    # @return [void] remove the object's data files from the workspace area
    def self.cleanup_workspace(druid)
      workspace_root_pathname = Pathname(Config.cleanup.local_workspace_root)
      workitem_pathname = Pathname(DruidTools::Druid.new(druid,workspace_root_pathname.to_s).path)
      # if work item's work dir is ab/123/cd/4567/ab123cd4567 then rm -r ab/123/cd/4567
      workitem_parent = workitem_pathname.parent
      self.remove_branch(workitem_parent)
      # now traverse ab/123/cd from bottom, and delete empty directories
      self.prune_druid_tree(workitem_parent.parent, workspace_root_pathname)
    end

    # @param druid [String] The identifier for the object whose data is to be removed
    # @return [void] remove copy of the data that was exported to preservation core
    def self.cleanup_export(druid)
      bag_dir = File.join(Config.cleanup.local_export_home, druid)
      self.remove_branch(bag_dir)
      tarfile = "#{bag_dir}.tar"
      self.remove_branch(tarfile)
    end

    # @param [Pathname,String] The full path of the branch to be removed
    # @return [void] Remove the specified directory and all its children
    def self.remove_branch(pathname)
      pathname = Pathname(pathname) if pathname.instance_of? String
      pathname.rmtree if pathname.exist?
    end

    # @param outermost_branch [Pathname] The branch at which pruning begins
    # @param workspace_root_pathname [Pathname] Do not prune past this point
    # @return [void] Ascend the druid tree and prune empty branches
    def self.prune_druid_tree(outermost_branch, workspace_root_pathname)
      while outermost_branch.children.size == 0
        outermost_branch.rmdir
        outermost_branch = outermost_branch.parent
        break if  outermost_branch == workspace_root_pathname
      end
    rescue
    end

  end

end