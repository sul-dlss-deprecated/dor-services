require 'dor/datastreams/content_metadata_ds'

module Dor
  module Publishable
    extend ActiveSupport::Concern
    include Identifiable
    include Governable
    include Describable
    include Itemizable

    included do
      has_metadata :name => "rightsMetadata", :type => ActiveFedora::OmDatastream, :label => 'Rights Metadata'
    end

    def build_rightsMetadata_datastream(ds)
      content_ds = self.admin_policy_object.first.datastreams['defaultObjectRights']
      ds.dsLabel = 'Rights Metadata'
      ds.ng_xml = content_ds.ng_xml.clone
      ds.content = ds.ng_xml.to_xml
    end

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

    def public_xml
      pub = Nokogiri::XML("<publicObject/>").root
      pub['id'] = pid
      pub['published'] = Time.now.xmlschema
      pub.add_child(self.datastreams['identityMetadata'].ng_xml.root.clone)
      pub.add_child(self.datastreams['contentMetadata'].public_xml.root.clone)
      pub.add_child(self.datastreams['rightsMetadata'].ng_xml.root.clone)
      rels = public_relationships.root
      pub.add_child(rels.clone) unless rels.nil? # TODO: Should never be nil in practice; working around an ActiveFedora quirk for testing
      pub.add_child(self.generate_dublin_core.root.clone)
      Nokogiri::XML(pub.to_xml) { |x| x.noblanks }.to_xml { |config| config.no_declaration }
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
          DigitalStacksService.transfer_to_document_store(pid, self.add_collection_reference, 'mods')
        end
      else
        # Clear out the document cache for this item
        DigitalStacksService.prune_purl_dir pid
      end
    end

  end
end