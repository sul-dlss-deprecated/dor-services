require 'moab_stanford'

module Dor
  module Shelvable
    extend ActiveSupport::Concern
    include Itemizable

    # Push file changes for shelve-able files into the stacks
    def shelve
      inventory_diff_xml = self.get_content_diff(:shelve)
      inventory_diff = Moab::FileInventoryDifference.parse(inventory_diff_xml)
      content_group_diff = inventory_diff.group_difference("content")
      deltas = content_group_diff.file_deltas

      if content_group_diff.rename_require_temp_files(deltas[:renamed])
        triplets = content_group_diff.rename_tempfile_triplets(deltas[:renamed])
        DigitalStacksService.rename_in_stacks self.pid, triplets.collect{|old,new,temp| [old,temp]}
        DigitalStacksService.rename_in_stacks self.pid, triplets.collect{|old,new,temp| [temp,new]}
      else
        DigitalStacksService.rename_in_stacks self.pid, deltas[:renamed]
      end
      DigitalStacksService.shelve_to_stacks   self.pid, deltas[:modified] + deltas[:added] + deltas[:copyadded].collect{|old,new| new}
      DigitalStacksService.remove_from_stacks self.pid, deltas[:deleted] + deltas[:copydeleted]
    end

  end
end
