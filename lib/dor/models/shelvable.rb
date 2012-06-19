module Dor
  module Shelvable
    extend ActiveSupport::Concern
    include Itemizable

    def shelve
      change_manifest = Dor::Versioning::FileInventoryDifference.new(self.get_content_diff('shelve'))

      DigitalStacksService.remove_from_stacks self.pid,  change_manifest.file_sets(:deleted,  :content)
      DigitalStacksService.rename_in_stacks   self.pid,  change_manifest.file_sets(:renamed,  :content)
      DigitalStacksService.shelve_to_stacks   self.pid, (change_manifest.file_sets(:modified, :content)+change_manifest.file_sets(:added, :content)).flatten
    end

  end
end
