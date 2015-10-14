require 'dor/datastreams/content_metadata_ds'

module Dor
  module Publishable
    extend ActiveSupport::Concern
    include Identifiable
    include Governable
    include Describable
    include Itemizable
    include Presentable

    included do
      has_metadata name: 'rightsMetadata', type: ActiveFedora::OmDatastream, label: 'Rights Metadata'
    end

    def build_rightsMetadata_datastream(ds)
      content_ds = admin_policy_object.datastreams['defaultObjectRights']
      ds.dsLabel = 'Rights Metadata'
      ds.ng_xml = content_ds.ng_xml.clone
      ds.content = ds.ng_xml.to_xml
    end

    def public_relationships
      include_elements = ['fedora:isMemberOf', 'fedora:isMemberOfCollection']
      rels_doc = Nokogiri::XML(datastreams['RELS-EXT'].content)
      rels_doc.xpath('/rdf:RDF/rdf:Description/*', 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#').each do |rel|
        unless include_elements.include?([rel.namespace.prefix, rel.name].join(':'))
          rel.next_sibling.remove if rel.next_sibling.content.strip.empty?
          rel.remove
        end
      end
      rels_doc
    end

    # Generate the public .xml for a PURL page.
    # @return [xml] The public xml for the item
    def public_xml
      pub = Nokogiri::XML('<publicObject/>').root
      pub['id'] = pid
      pub['published'] = Time.now.xmlschema
      pub['publishVersion'] = 'dor-services/' + Dor::VERSION
      release_xml = Nokogiri(generate_release_xml).xpath('//release')

      im = datastreams['identityMetadata'].ng_xml.clone
      im.search('//release').each(&:remove) # remove any <release> tags from public xml which have full history

      pub.add_child(im.root) # add in modified identityMetadata datastream
      pub.add_child(datastreams['contentMetadata'].public_xml.root.clone)
      pub.add_child(datastreams['rightsMetadata'].ng_xml.root.clone)

      rels = public_relationships.root
      pub.add_child(rels.clone) unless rels.nil? # TODO: Should never be nil in practice; working around an ActiveFedora quirk for testing
      pub.add_child(generate_dublin_core.root.clone)
      @public_xml_doc = pub # save this for possible IIIF Presentation manifest
      pub.add_child(Nokogiri(generate_release_xml).root.clone) unless release_xml.children.size == 0 # If there are no release_tags, this prevents an empty <releaseData/> from being added
      # Note we cannot base this on if an individual object has release tags or not, because the collection may cause one to be generated for an item,
      # so we need to calculate it and then look at the final result.s
      new_pub = Nokogiri::XML(pub.to_xml, &:noblanks)
      new_pub.encoding = 'UTF-8'
      new_pub.to_xml
    end

    # Copies this object's public_xml to the Purl document cache if it is world discoverable
    #  otherwise, it prunes the object's metadata from the document cache
    def publish_metadata
      rights = datastreams['rightsMetadata'].ng_xml.clone.remove_namespaces!
      if rights.at_xpath("//rightsMetadata/access[@type='discover']/machine/world")
        dc_xml = generate_dublin_core.to_xml(&:no_declaration)
        DigitalStacksService.transfer_to_document_store(pid, dc_xml, 'dc')
        DigitalStacksService.transfer_to_document_store(pid, datastreams['identityMetadata'].to_xml, 'identityMetadata')
        DigitalStacksService.transfer_to_document_store(pid, datastreams['contentMetadata'].to_xml, 'contentMetadata')
        DigitalStacksService.transfer_to_document_store(pid, datastreams['rightsMetadata'].to_xml, 'rightsMetadata')
        DigitalStacksService.transfer_to_document_store(pid, public_xml, 'public')
        DigitalStacksService.transfer_to_document_store(pid, generate_public_desc_md, 'mods') if metadata_format == 'mods'
        DigitalStacksService.transfer_to_document_store(pid, build_iiif_manifest(@public_xml_doc), 'manifest') if iiif_presentation_manifest_needed? @public_xml_doc
      else
        # Clear out the document cache for this item
        DigitalStacksService.prune_purl_dir pid
      end
    end

    # Call dor services app to have it publish the metadata
    def publish_metadata_remotely
      dor_services = RestClient::Resource.new(Config.dor_services.url + "/v1/objects/#{pid}/publish")
      dor_services.post ''
      dor_services.url
    end
  end
end
