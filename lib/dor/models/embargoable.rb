module Dor
  module Embargoable
    extend ActiveSupport::Concern
    include Dor::Publishable
    
    included do
      has_metadata :name => 'embargoMetadata', :type => Dor::EmbargoMetadataDS, :label => 'Embargo metadata'
    end

    # These methods manipulate the object for embargo purposes
    # They assume the object has embargoMetadata, rightsMetadata, and events datastreams
    
    # Manipulates datastreams in the object when embargo is lifted:
    # Sets embargo status to released in embargoMetadata
    # Modifies rightsMetadata to remove embargoReleaseDate and updates/adds access from embargoMetadata/releaseAccess
    # @param [String] release_agent name of the person, application or thing that released embargo
    # @note The caller should save the object to fedora to commit the changes
    def release_embargo(release_agent="unknown")
      # Set status to released
      embargo_md = datastreams['embargoMetadata']
      embargo_md.status = 'released'
      
      # Remove all read acces nodes
      rights_xml = datastreams['rightsMetadata'].ng_xml
      rights_xml.xpath("//rightsMetadata/access[@type='read']").each { |n| n.remove }
      
      # Replace rights <access> nodes with those from embargoMetadta
      release_access = embargo_md.release_access_node
      release_access.xpath('//releaseAccess/access').each do |new_access|
        access_sibling = rights_xml.at_xpath("//rightsMetadata/access[last()]")
        if(access_sibling)
          access_sibling.add_next_sibling(new_access.clone)
        else
          rights_xml.root.add_child(new_access.clone)
        end
      end
      
      datastreams['events'].add_event("embargo", release_agent, "Embargo released")
    end
		def update_embargo(new_date)
			if not embargoMetadata.status == 'embargoed'
				raise 'You cannot change the embargo date of an item thant isnt embargoed.'
			end
			if new_date.past?
			  raise 'You cannot set the embargo date to a past date.'
			end
			updated=false
			self.rightsMetadata.ng_xml.search('//embargoReleaseDate').each do |node|
				node.content=new_date.beginning_of_day.utc.xmlschema
				updated=true
			end
			self.rightsMetadata.content=self.rightsMetadata.ng_xml.to_s
			self.rightsMetadata.save
			if not updated
				raise 'No release date in rights metadata, cannot proceed!'
			end
			self.embargoMetadata.ng_xml.xpath('//releaseDate').each do |node|
				node.content=new_date.beginning_of_day.utc.xmlschema
			end
			self.embargoMetadata.content=self.embargoMetadata.ng_xml.to_s
			self.embargoMetadata.save
		end
  end
end
