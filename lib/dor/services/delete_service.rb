# frozen_string_literal: true

module Dor
  # Remove all traces of the object's data files from the workspace and export areas
  class DeleteService
    # Tries to remove any exsitence of the object in our systems
    #   Does the following:
    #   - Removes item from Fedora/Solr
    #   - Removes content from dor workspace
    #   - Removes content from assembly workspace
    #   - Removes content from sdr export area
    #   - Removes content from stacks
    #   - Removes content from purl
    #   - Removes active workflows
    # @param [String] druid id of the object you wish to remove
    def self.destroy(druid)
      new(druid).destroy
    end

    def initialize(druid)
      @druid = druid
    end

    def destroy
      CleanupService.cleanup_by_druid druid
      cleanup_stacks
      cleanup_purl_doc_cache
      remove_active_workflows
      delete_from_dor
    end

    private

    attr_reader :druid

    def cleanup_stacks
      DruidTools::StacksDruid.new(druid, Config.stacks.local_stacks_root).prune!
    end

    def cleanup_purl_doc_cache
      DruidTools::PurlDruid.new(druid, Config.stacks.local_document_cache_root).prune!
    end

    def remove_active_workflows
      Dor::Config.workflow.client.delete_all_workflows(pid: druid)
    end

    # Delete an object from DOR.
    #
    # @param [string] pid the druid
    def delete_from_dor
      Dor::Config.fedora.client["objects/#{druid}"].delete
      Dor::SearchService.solr.delete_by_id(druid)
      Dor::SearchService.solr.commit
    end
  end
end
