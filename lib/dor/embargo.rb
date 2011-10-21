require 'datastreams/embargo_metadata_ds'
require 'datastreams/events_ds'

module Dor
  
  # These methods manipulate the object for embargo purposes
  # They assume the object has embargoMetadata, rightsMetadata, and events datastreams
  module Embargo
    
    # Manipulates datastreams in the object when embargo is lifted:
    # Sets embargo status to released in embargoMetadata
    # Modifies rightsMetadata to remove embargoReleaseDate and updates/adds access from embargoMetadata/releaseAccess
    # @param [String] release_agent name of the person, application or thing that released embargo
    # @note The caller should save the object to fedora to commit the changes
    def release_embargo(release_agent="unknown")
      # Set status to released
      embargo_md = datastreams['embargoMetadata']
      embargo_md.status = 'released'
      
      # Remove embargoReleaseDate from rights
      rights_xml = datastreams['rightsMetadata'].ng_xml
      rights_xml.xpath("//rightsMetadata/access[@type='read']/machine/embargoReleaseDate").remove
      
      # Replace rights <access> nodes with those from embargoMetadta
      release_access = embargo_md.release_access_node
      release_access.xpath('//releaseAccess/access').each do |new_access|
        type = new_access['type']
        rights_xml.xpath("//rightsMetadata/access[@type='#{type}']").remove
        access_sibling = rights_xml.at_xpath("//rightsMetadata/access[last()]")
        if(access_sibling)
          access_sibling.add_next_sibling(new_access.clone)
        else
          rights_xml.root.add_child(new_access.clone)
        end
      end
      
      datastreams['events'].add_event("embargo", release_agent, "Embargo released")
    end
  end
end