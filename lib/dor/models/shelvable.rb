require 'moab_stanford'

module Dor
  module Shelvable
    extend ActiveSupport::Concern
    include Itemizable

    # Push file changes for shelve-able files into the stacks
    def shelve
      workspace_druid = DruidTools::Druid.new(id,Config.stacks.local_workspace_root)

      stacks_druid = DruidTools::StacksDruid.new id, Config.stacks.local_stacks_root
      stacks_object_pathname = Pathname(stacks_druid.path)

      inventory_diff_xml = self.get_content_diff(:shelve)
      inventory_diff = Moab::FileInventoryDifference.parse(inventory_diff_xml)
      content_diff = inventory_diff.group_difference("content")

      DigitalStacksService.remove_from_stacks(stacks_object_pathname, content_diff)
      DigitalStacksService.rename_in_stacks(stacks_object_pathname, content_diff)
      DigitalStacksService.shelve_to_stacks(workspace_druid, stacks_object_pathname, content_diff)
    end

  end
end
