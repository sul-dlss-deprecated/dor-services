module Dor
  module Shelvable
    extend ActiveSupport::Concern
    include Itemizable

    # Pushs file changes for shelve-able files into the stacks
    def shelve
      # TODO: Switch to Moab versioning service
      change_manifest = Dor::Versioning::FileInventoryDifference.new(self.get_content_diff(:shelve))

      DigitalStacksService.remove_from_stacks self.pid,  change_manifest.file_sets(:deleted,  :content)
      DigitalStacksService.rename_in_stacks   self.pid,  change_manifest.file_sets(:renamed,  :content)
      DigitalStacksService.shelve_to_stacks   self.pid, (change_manifest.file_sets(:modified, :content)+change_manifest.file_sets(:added, :content)).flatten
    end

  end
end
