# frozen_string_literal: true

module Dor
  # Responsible for decommissioning objects
  class DecommissionService
    # @param [Dor::Item] object
    def initialize(object)
      @object = object
    end

    attr_reader :object

    # Clears RELS-EXT relationships, sets the isGovernedBy relationship to the SDR Graveyard APO
    # @param [String] tag optional String of text that is concatenated to the identityMetadata/tag "Decommissioned : "
    def decommission(tag)
      # remove isMemberOf and isMemberOfCollection relationships
      object.clear_relationship :is_member_of
      object.clear_relationship :is_member_of_collection
      # remove isGovernedBy relationship
      object.clear_relationship :is_governed_by
      # add isGovernedBy to graveyard APO druid:sw909tc7852
      # SEARCH BY dc title for 'SDR Graveyard'
      object.add_relationship :is_governed_by, ActiveFedora::Base.find(Dor::SearchService.sdr_graveyard_apo_druid)
      # eliminate contentMetadata. set it to <contentMetadata/> ?
      object.contentMetadata.content = '<contentMetadata/>'
      # eliminate rightsMetadata. set it to <rightsMetadata/> ?
      object.rightsMetadata.content = '<rightsMetadata/>'
      TagService.add object, "Decommissioned : #{tag}"
    end
  end
end
