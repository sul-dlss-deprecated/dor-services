# frozen_string_literal: true

module Dor
  # Time limits and processes for embargoed materials.
  module Embargoable
    extend ActiveSupport::Concern

    included do
      has_metadata name: 'embargoMetadata', type: Dor::EmbargoMetadataDS, label: 'Embargo metadata'
    end

    # Manipulates datastreams in the object when embargo is lifted:
    # Sets embargo status to released in embargoMetadata
    # Modifies rightsMetadata to remove embargoReleaseDate and updates/adds access from embargoMetadata/releaseAccess
    # @param [String] release_agent name of the person, application or thing that released embargo
    # @note The caller should save the object to fedora to commit the changes
    def release_embargo(release_agent = 'unknown')
      embargo_service.release(release_agent)
    end

    def release_20_pct_vis_embargo(release_agent = 'unknown')
      embargo_service.release_20_pct_vis(release_agent)
    end

    def embargoed?
      embargoMetadata.status == 'embargoed'
    end

    def update_embargo(new_date)
      embargo_service.update(new_date)
    end

    def embargo_service
      EmbargoService.new(self)
    end
  end
end
