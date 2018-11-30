# frozen_string_literal: true

module Dor
  # Push file changes for shelve-able files into the stacks
  class ShelvingService
    def self.shelve(work)
      new(work).shelve
    end

    def initialize(work)
      @work = work
    end

    private

    attr_reader :work

    def shelve
      # retrieve the differences between the current contentMetadata and the previously ingested version
      diff = shelve_diff
      stacks_object_pathname = stacks_location
      # determine the location of the object's files in the stacks area
      stacks_druid = DruidTools::StacksDruid.new work.id, stacks_object_pathname
      stacks_object_pathname = Pathname(stacks_druid.path)
      # determine the location of the object's content files in the workspace area
      workspace_druid = DruidTools::Druid.new(work.id, Config.stacks.local_workspace_root)
      workspace_content_pathname = workspace_content_dir(diff, workspace_druid)
      # delete, rename, or copy files to the stacks area
      DigitalStacksService.remove_from_stacks(stacks_object_pathname, diff)
      DigitalStacksService.rename_in_stacks(stacks_object_pathname, diff)
      DigitalStacksService.shelve_to_stacks(workspace_content_pathname, stacks_object_pathname, diff)
    end

    # retrieve the differences between the current contentMetadata and the previously ingested version
    # (filtering to select only the files that should be shelved to stacks)
    def shelve_diff
      inventory_diff = work.get_content_diff(:shelve)
      inventory_diff.group_difference('content')
    end

    # Find the location of the object's content files in the workspace area
    # @param [Moab::FileGroupDifference] content_diff The differences between the current contentMetadata and the previously ingested version
    # @param [DruidTools::Druid] workspace_druid the location of the object's files in the workspace area
    # @return [Pathname] The location of the object's content files in the workspace area
    def workspace_content_dir(content_diff, workspace_druid)
      deltas = content_diff.file_deltas
      filelist = deltas[:modified] + deltas[:added] + deltas[:copyadded].collect { |_old, new| new }
      return nil if filelist.empty?

      Pathname(workspace_druid.find_filelist_parent('content', filelist))
    end

    # get the stack location based on the contentMetadata stacks attribute
    # or using the default value from the config file if it doesn't exist
    def stacks_location
      return Config.stacks.local_stacks_root unless work.contentMetadata&.stacks.present?

      location = work.contentMetadata.stacks[0]
      return location if location.start_with? '/' # Absolute stacks path

      raise "stacks attribute for item: #{work.id} contentMetadata should start with /. The current value is #{location}"
    end
  end
end
