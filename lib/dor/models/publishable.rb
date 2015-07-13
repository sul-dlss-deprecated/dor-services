require 'dor/datastreams/content_metadata_ds'

module Dor
  module Publishable
    extend ActiveSupport::Concern
    include Identifiable
    include Governable
    include Describable
    include Itemizable
    include Presentable
    include Rightsable

    def public_relationships
      include_elements = ['fedora:isMemberOf','fedora:isMemberOfCollection']
      rels_doc = Nokogiri::XML(self.datastreams['RELS-EXT'].content)
      rels_doc.xpath('/rdf:RDF/rdf:Description/*', { 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' }).each do |rel|
        unless include_elements.include?([rel.namespace.prefix,rel.name].join(':'))
          rel.next_sibling.remove if rel.next_sibling.content.strip.empty?
          rel.remove
        end
      end
      rels_doc
    end

    #Generate the public .xml for a PURL page.
    #@return [xml] The public xml for the item
    #
    def public_xml
      pub = Nokogiri::XML("<publicObject/>").root
      pub['id'] = pid
      pub['published'] = Time.now.xmlschema
      release_xml=Nokogiri(self.generate_release_xml).xpath('//release')

      im=self.datastreams['identityMetadata'].ng_xml.clone
      im.search('//release').each {|node| node.remove} # remove any <release> tags from public xml which have full history
      im.root.add_child(release_xml) 

      pub.add_child(im.root) # add in modified identityMetadata datastream
      pub.add_child(self.datastreams['contentMetadata'].public_xml.root.clone)
      pub.add_child(self.datastreams['rightsMetadata'].ng_xml.root.clone)

      rels = public_relationships.root
      pub.add_child(rels.clone) unless rels.nil? # TODO: Should never be nil in practice; working around an ActiveFedora quirk for testing
      pub.add_child(self.generate_dublin_core.root.clone)
      @public_xml_doc = pub # save this for possible IIIF Presentation manifest
      pub.add_child(Nokogiri(self.generate_release_xml).root.clone) unless release_xml.children.size == 0 #If there are no release_tags, this prevents an empty <releaseData/> from being added
      #Note we cannot base this on if an individual object has release tags or not, because the collection may cause one to be generated for an item, so we need to calculate it and then look at the final result
      new_pub = Nokogiri::XML(pub.to_xml) { |x| x.noblanks }
      new_pub.encoding = 'UTF-8'
      new_pub.to_xml
    end

    # Copies this object's public_xml to the Purl document cache if it is world discoverable
    #  otherwise, it prunes the object's metadata from the document cache
    def publish_metadata
      rights = datastreams['rightsMetadata'].ng_xml.clone.remove_namespaces!
      if(rights.at_xpath("//rightsMetadata/access[@type='discover']/machine/world"))
        dc_xml = self.generate_dublin_core.to_xml {|config| config.no_declaration}
        DigitalStacksService.transfer_to_document_store(pid, dc_xml, 'dc')
        DigitalStacksService.transfer_to_document_store(pid, self.datastreams['identityMetadata'].to_xml, 'identityMetadata')
        DigitalStacksService.transfer_to_document_store(pid, self.datastreams['contentMetadata'].to_xml, 'contentMetadata')
        DigitalStacksService.transfer_to_document_store(pid, self.datastreams['rightsMetadata'].to_xml, 'rightsMetadata')
        DigitalStacksService.transfer_to_document_store(pid, public_xml, 'public')
        if self.metadata_format == 'mods'
          DigitalStacksService.transfer_to_document_store(pid, self.generate_public_desc_md, 'mods')
        end
        if iiif_presentation_manifest_needed? @public_xml_doc
          DigitalStacksService.transfer_to_document_store(pid, build_iiif_manifest(@public_xml_doc), 'manifest')
        end
      else
        # Clear out the document cache for this item
        DigitalStacksService.prune_purl_dir pid
      end
    end
    #call the dor services app to have it publish the metadata
    def publish_metadata_remotely
      dor_services = RestClient::Resource.new(Config.dor_services.url+"/v1/objects/#{pid}/publish")
      dor_services.post ''
      dor_services.url
    end
  end

end
