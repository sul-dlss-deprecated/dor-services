require 'dor/datastreams/content_metadata_ds'
require 'fileutils'

module Dor
  module Publishable
    extend ActiveSupport::Concern

    # Compute the thumbnail for this object following the rules at https://consul.stanford.edu/display/chimera/The+Rules+of+Thumb
    # @return [String] the computed thumb filename, with the druid prefix and a slash in front of it, e.g. oo000oo0001/filenamewith space.jp2
    def thumb
       return unless respond_to?(:contentMetadata) && !contentMetadata.nil?
       cm = contentMetadata.ng_xml
       mime_type_finder = "@mimetype='image/jp2' or @mimeType='image/jp2'" # allow the mimetype attribute to be lower or camelcase when searching to make it more robust
       thumb_image=nil

       # these are the finders we will use to search for a thumb resource in contentMetadata, they will be searched in the order provided, stopping when one is reached
       thumb_xpath_finders = [
           {image_type: 'local', finder: "/contentMetadata/resource[@type='thumb' and @thumb='yes']/file[#{mime_type_finder}]"},      # first find a file of mimetype jp2 explicitly marked as a thumb in the resource type and with a thumb=yes attribute
           {image_type: 'external', finder: "/contentMetadata/resource[@type='thumb' and @thumb='yes']/externalFile[#{mime_type_finder}]"}, # same thing for external files
           {image_type: 'local', finder: "/contentMetadata/resource[(@type='page' or @type='image') and @thumb='yes']/file[#{mime_type_finder}]"},# next find any image or page resource types with the thumb=yes attribute of mimetype jp2
           {image_type: 'external', finder: "/contentMetadata/resource[(@type='page' or @type='image') and @thumb='yes']/externalFile[#{mime_type_finder}]"},# same thing for external file
           {image_type: 'local', finder: "/contentMetadata/resource[@type='thumb']/file[#{mime_type_finder}]"}, # next find a file of mimetype jp2 and resource type=thumb but not marked with the thumb directive
           {image_type: 'external', finder: "/contentMetadata/resource[@type='thumb']/externalFile[#{mime_type_finder}]"}, # same thing for external file
           {image_type: 'local', finder: "/contentMetadata/resource[@type='page' or @type='image']/file[#{mime_type_finder}]"}, # finally find the first page or image resource of mimetype jp2
           {image_type: 'external', finder: "/contentMetadata/resource[@type='page' or @type='image']/externalFile[#{mime_type_finder}]"} # same thing for external file
         ]
              
       thumb_xpath_finders.each do |search_path|
         thumb_files = cm.xpath(search_path[:finder]) # look for a thumb  
         if thumb_files.size > 0   # if we find one, return the filename based on whether it is a local file or external file
           if search_path[:image_type] == 'local'
             thumb_image="#{remove_druid_prefix}/#{thumb_files[0]['id']}"
           else
             thumb_image="#{remove_druid_prefix(thumb_files[0]['objectId'])}/#{thumb_files[0]['fileId']}"
           end
           break  # break out of the loop so we stop searching
         end
       end 
              
       thumb_image
    end

    # Return a URI encoded version of the thumb image for use by indexers (leaving the extension of the filename)
    # @return [String] URI encoded version of the thumb with the druid prefix, e.g. oo000oo0001%2Ffilenamewith%20space.jp2
    def encoded_thumb
      thumb_image = thumb # store the result locally, so we don't have to compute each time we use it below
      return unless thumb_image
      thumb_druid=thumb_image.split('/').first # the druid (before the first slash)
      thumb_filename=thumb_image.split(/#{pid_regex}[\/]/).last # everything after the druid
      "#{thumb_druid}%2F#{ERB::Util.url_encode(thumb_filename)}"
    end
    
    # Return a full qualified thumbnail image URL if the thumb is computable
    # @return [String] fully qualified image URL for the computed thumbnail, e.g. https://stacks.stanford.edu/image/iiif/oo000oo0001%2Ffilenamewith%20space/full
    def thumb_url
      return unless encoded_thumb
      thumb_basename=File.basename(encoded_thumb, File.extname(encoded_thumb)) # strip the extension for URL generation
      "https://#{Dor::Config.stacks.host}/image/iiif/#{thumb_basename}/full/!400,400/0/default.jpg"
    end
    
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
        dc_xml = generate_dublin_core.to_xml {|config| config.no_declaration}
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
    # When publishing a PURL, we drop a `aa11bb2222` file into the `local_recent_changes` folder
    # to notify other applications watching the filesystem (i.e., purl-fetcher).
    # We also remove any .deletes entry that may have left over from a previous removal
    # @param [String] local_recent_changes usually `/purl/recent_changes`
    def publish_notify_on_success(local_recent_changes = Config.stacks.local_recent_changes)
      raise ArgumentError, "Missing local_recent_changes directory: #{local_recent_changes}" unless File.directory?(local_recent_changes)
      id = pid.gsub(/^druid:/, '')
      FileUtils.touch(File.join(local_recent_changes, id))
      begin
        DruidTools::Druid.new(id, Dor::Config.stacks.local_document_cache_root).deletes_delete_record
      rescue Errno::EACCES
        Dor.logger.warn "Access denied while trying to remove .deletes file for druid:#{id}"
      end
    end
  end
end
