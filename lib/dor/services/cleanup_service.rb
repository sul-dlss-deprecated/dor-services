require 'pathname'

module Dor

  # Remove all traces of the object's data files from the workspace and export areas
  class CleanupService

    # @param [LyberCore::Robots::WorkItem] dor_item The DOR work item whose workspace should be cleaned up
    # @return [void] Delete all workspace and export entities for the druid
    def self.cleanup(dor_item)
      druid = dor_item.respond_to? :druid ? dor_item.druid : dor_item.id
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

    # Tries to remove any exsitence of the object in our systems
    #   Does the following:
    #   - Removes item from Dor/Fedora/Solr
    #   - Removes content from dor workspace
    #   - Removes content from assembly workspace
    #   - Removes content from sdr export area
    #   - Removes content from stacks
    #   - Removes content from purl
    #   - Removes active workflows
    # @param [String] druid id of the object you wish to remove
    def self.nuke!(druid)
      cleanup_by_druid druid
      cleanup_stacks druid
      cleanup_purl_doc_cache druid
      remove_active_workflows druid
      delete_from_dor druid
    end

    def self.cleanup_stacks(druid)
      DruidTools::StacksDruid.new(druid, Config.stacks.local_storage_root).prune!
    end

    def self.cleanup_purl_doc_cache(druid)
      DruidTools::PurlDruid.new(druid, Config.stacks.local_document_cache_root).prune!
    end

    def self.remove_active_workflows(druid)
      %w(dor sdr).each do |repo|
        dor_wfs = Dor::WorkflowService.get_workflows(druid, repo)
        dor_wfs.each { |wf| Dor::WorkflowService.delete_workflow(repo, druid, wf) }
      end
    end

    # Delete an object from DOR.
    #
    # @param [string] pid the druid
    def self.delete_from_dor(pid)
      Dor::Config.fedora.client["objects/#{pid}"].delete
      Dor::SearchService.solr.delete_by_id(pid)
      Dor::SearchService.solr.commit
    end
  end 

end


    
