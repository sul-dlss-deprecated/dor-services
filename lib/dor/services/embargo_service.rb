# frozen_string_literal: true

module Dor
  # Sets up and removes embargos on an object
  # This assumes the object has embargoMetadata, rightsMetadata, and events datastreams
  class EmbargoService
    def initialize(obj)
      @obj = obj
    end

    # Lift the embargo from the object
    # Sets embargo status to released in embargoMetadata
    # Modifies rightsMetadata to remove embargoReleaseDate and updates/adds access from embargoMetadata/releaseAccess
    # @param [String] release_agent name of the person, application or thing that released embargo
    # @note The caller should save the object to fedora to commit the changes
    def release(release_agent)
      # Set status to released
      embargoMetadata.status = 'released'

      # Remove all read acces nodes
      rights_xml = rightsMetadata.ng_xml
      rightsMetadata.ng_xml_will_change!
      rights_xml.xpath("//rightsMetadata/access[@type='read']").each(&:remove)

      # Replace rights <access> nodes with those from embargoMetadta
      release_access = embargoMetadata.release_access_node
      release_access.xpath('//releaseAccess/access').each do |new_access|
        access_sibling = rights_xml.at_xpath('//rightsMetadata/access[last()]')
        if access_sibling
          access_sibling.add_next_sibling(new_access.clone)
        else
          rights_xml.root.add_child(new_access.clone)
        end
      end

      events.add_event('embargo', release_agent, 'Embargo released')
    end

    def release_20_pct_vis(release_agent)
      # Set status to released
      embargoMetadata.twenty_pct_status = 'released'

      # Remove all read acces nodes
      rights_xml = rightsMetadata.ng_xml
      rightsMetadata.ng_xml_will_change!
      rights_xml.xpath("//rightsMetadata/access[@type='read']").each(&:remove)

      # Replace rights <access> nodes with 1 machine/world node
      access_sibling = rights_xml.at_xpath('//rightsMetadata/access[last()]')
      if access_sibling
        access_sibling.add_next_sibling(world_doc.root.clone)
      else
        rights_xml.root.add_child(world_doc.root.clone)
      end

      events.add_event('embargo', release_agent, '20% Visibility Embargo released')
    end

    def update(new_date)
      raise ArgumentError, 'You cannot change the embargo date of an item that is not embargoed.' if embargoMetadata.status != 'embargoed'
      raise ArgumentError, 'You cannot set the embargo date to a past date.' if new_date.past?

      updated = false
      rightsMetadata.ng_xml.search('//embargoReleaseDate').each do |node|
        node.content = new_date.beginning_of_day.utc.xmlschema
        updated = true
      end
      rightsMetadata.ng_xml_will_change!
      rightsMetadata.save
      raise 'No release date in rights metadata, cannot proceed!' unless updated

      embargoMetadata.ng_xml.xpath('//releaseDate').each do |node|
        node.content = new_date.beginning_of_day.utc.xmlschema
      end
      embargoMetadata.ng_xml_will_change!
      embargoMetadata.save
    end

    private

    attr_reader :obj

    delegate :rightsMetadata, :embargoMetadata, :events, to: :obj

    def world_doc
      Nokogiri::XML::Builder.new do |xml|
        xml.access(type: 'read') do
          xml.machine { xml.world }
        end
      end.doc
    end
  end
end
