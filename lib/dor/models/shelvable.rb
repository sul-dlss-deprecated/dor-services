require 'moab_stanford'

module Dor
  module Shelvable
    extend ActiveSupport::Concern
    include Itemizable

    # Push file changes for shelve-able files into the stacks
    def shelve
      # retrieve the differences between the current contentMetadata and the previously ingested version
      shelve_diff = get_shelve_diff
      # determine the location of the object's files in the stacks area
      stacks_druid = DruidTools::StacksDruid.new id, Config.stacks.local_stacks_root
      stacks_object_pathname = Pathname(stacks_druid.path)
      # determine the location of the object's content files in the workspace area
      workspace_druid = DruidTools::Druid.new(id,Config.stacks.local_workspace_root)
      workspace_content_pathname = workspace_content_dir(shelve_diff, workspace_druid)
      # delete, rename, or copy files to the stacks area
      DigitalStacksService.remove_from_stacks(stacks_object_pathname, shelve_diff)
      DigitalStacksService.rename_in_stacks(stacks_object_pathname, shelve_diff)
      DigitalStacksService.shelve_to_stacks(workspace_content_pathname, stacks_object_pathname, shelve_diff)
    end

    # retrieve the differences between the current contentMetadata and the previously ingested version
    # (filtering to select only the files that should be shelved to stacks)
    def get_shelve_diff
      inventory_diff_xml = self.get_content_diff(:shelve)
      inventory_diff = Moab::FileInventoryDifference.parse(inventory_diff_xml)
      shelve_diff = inventory_diff.group_difference("content")
      shelve_diff
    end

    # Find the location of the object's content files in the workspace area
    # @param [Moab::FileGroupDifference] content_diff The differences between the current contentMetadata and the previously ingested version
    # @param [DruidTools::Druid] workspace_druid the location of the object's files in the workspace area
    # @return [Pathname] The location of the object's content files in the workspace area
    def workspace_content_dir (content_diff, workspace_druid)
      deltas = content_diff.file_deltas
      filelist = deltas[:modified] + deltas[:added] + deltas[:copyadded].collect{|old,new| new}
      return nil if filelist.empty?
      content_pathname = Pathname(workspace_druid.find_filelist_parent('content', filelist))
      content_pathname
    end

  end
end
