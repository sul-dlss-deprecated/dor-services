module Dor
  module Shelvable
    extend ActiveSupport::Concern
    include Itemizable

    def shelve
      change_manifest = Dor::Versioning::FileInventoryDifference.new(self.get_content_diff)

      change_manifest.file_sets(:deleted,  :content).each { |set| DigitalStacksService.remove_from_stacks *set }
      change_manifest.file_sets(:renamed,  :content).each { |set| DigitalStacksService.rename_in_stacks   *set }
      change_manifest.file_sets(:modified, :content).each { |set| DigitalStacksService.shelve_to_stacks   *set }
      change_manifest.file_sets(:added,    :content).each { |set| DigitalStacksService.shelve_to_stacks   *set }
    end

  end
end
