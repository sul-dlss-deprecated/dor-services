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
      rels_doc.xpath('/rdf:RDF/rdf:Description/*', { 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' }).each do |rel|
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
      rights = datastreams['rightsMetadata'].ng_xml.clone.remove_namespaces!
      if rights.at_xpath("//rightsMetadata/access[@type='discover']/machine/world")
        dc_xml = generate_dublin_core.to_xml { |config| config.no_declaration }
        DigitalStacksService.transfer_to_document_store(pid, dc_xml, 'dc')
        %w(identityMetadata contentMetadata rightsMetadata).each do |stream|
          DigitalStacksService.transfer_to_document_store(pid, datastreams[stream].content.to_s, stream) if datastreams[stream]
        end
        DigitalStacksService.transfer_to_document_store(pid, public_xml, 'public')
        DigitalStacksService.transfer_to_document_store(pid, generate_public_desc_md, 'mods')
        publish_notify_on_success
      else
        # Clear out the document cache for this item
        DigitalStacksService.prune_purl_dir pid
        publish_delete_on_success
      end
    end

    # Call dor services app to have it publish the metadata
    def publish_metadata_remotely
      dor_services = Dor::Config.dor_services.rest_client
      endpoint = dor_services["v1/objects/#{pid}/publish"]
      endpoint.post ''
      endpoint.url
    end

    ##
    # When publishing a PURL, we notify purl-fetcher of changes.
    # If the purl service isn't configured, instead we drop a `aa11bb2222` file into the `local_recent_changes` folder
    # to notify other applications watching the filesystem (i.e., purl-fetcher).
    # We also remove any .deletes entry that may have left over from a previous removal
    def publish_notify_on_success
      id = pid.gsub(/^druid:/, '')

      if Dor::Config.purl_services.url
        purl_services = Dor::Config.purl_services.rest_client
        purl_services["purls/#{id}"].post ''
      else
        local_recent_changes = Config.stacks.local_recent_changes
        raise ArgumentError, "Missing local_recent_changes directory: #{local_recent_changes}" unless File.directory?(local_recent_changes)

        FileUtils.touch(File.join(local_recent_changes, id))
        begin
          DruidTools::Druid.new(id, Dor::Config.stacks.local_document_cache_root).deletes_delete_record
        rescue Errno::EACCES
          Dor.logger.warn "Access denied while trying to remove .deletes file for druid:#{id}"
        end
      end
    end

    ##
    # When publishing a PURL, we notify purl-fetcher of changes.
    def publish_delete_on_success
      return unless Dor::Config.purl_services.url
      id = pid.gsub(/^druid:/, '')

      purl_services = Dor::Config.purl_services.rest_client
      purl_services["purls/#{id}"].delete
    end
  end
end
