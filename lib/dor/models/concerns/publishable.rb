# frozen_string_literal: true

require 'dor/datastreams/content_metadata_ds'
require 'fileutils'

module Dor
  module Publishable
    extend Deprecation
    extend ActiveSupport::Concern
    self.deprecation_horizon = 'dor-services version 7.0.0'

    # Compute the thumbnail for this object following the rules at https://consul.stanford.edu/display/chimera/The+Rules+of+Thumb
    # Used by PublicXmlService
    # @return [String] the computed thumb filename, with the druid prefix and a slash in front of it, e.g. oo000oo0001/filenamewith space.jp2
    def thumb
      ThumbnailService.new(self).thumb
    end
    deprecation_deprecate :thumb

    # Return a URI encoded version of the thumb image for use by indexers (leaving the extension of the filename)
    # @return [String] URI encoded version of the thumb with the druid prefix, e.g. oo000oo0001%2Ffilenamewith%20space.jp2
    def encoded_thumb
      thumb_image = thumb # store the result locally, so we don't have to compute each time we use it below
      return unless thumb_image

      thumb_druid = thumb_image.split('/').first # the druid (before the first slash)
      thumb_filename = thumb_image.split(/#{pid_regex}[\/]/).last # everything after the druid
      "#{thumb_druid}%2F#{ERB::Util.url_encode(thumb_filename)}"
    end
    deprecation_deprecate :encoded_thumb

    # Return a full qualified thumbnail image URL if the thumb is computable
    # @return [String] fully qualified image URL for the computed thumbnail, e.g. https://stacks.stanford.edu/image/iiif/oo000oo0001%2Ffilenamewith%20space/full
    def thumb_url
      return unless encoded_thumb

      thumb_basename = File.basename(encoded_thumb, File.extname(encoded_thumb)) # strip the extension for URL generation
      "https://#{Dor::Config.stacks.host}/image/iiif/#{thumb_basename}/full/!400,400/0/default.jpg"
    end
    deprecation_deprecate :thumb_url

    # strips away the relationships that should not be shown in public desc metadata
    # @return [Nokogiri::XML]
    def public_relationships
      include_elements = ['fedora:isMemberOf', 'fedora:isMemberOfCollection', 'fedora:isConstituentOf']
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
      PublicXmlService.new(self).to_xml
    end

    # Copies this object's public_xml to the Purl document cache if it is world discoverable
    #  otherwise, it prunes the object's metadata from the document cache
    def publish_metadata
      PublishMetadataService.publish(self)
    end
    deprecation_deprecate publish_metadata: 'use Dor::PublishMetadataService.publish(obj) instead or use publish_metadata_remotely'

    # Call dor services app to have it publish the metadata
    def publish_metadata_remotely
      dor_services = Dor::Config.dor_services.rest_client
      endpoint = dor_services["v1/objects/#{pid}/publish"]
      endpoint.post ''
      endpoint.url
    end
  end
end
