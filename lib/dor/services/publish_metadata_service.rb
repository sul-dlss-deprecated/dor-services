# frozen_string_literal: true

module Dor
  # Merges contentMetadata from several objects into one.
  class PublishMetadataService
    # @param [Dor::Item] item the object to be publshed
    def self.publish(item)
      new(item).publish
    end

    def initialize(item)
      @item = item
    end

    # Appends contentMetadata file resources from the source objects to this object
    def publish
      return unpublish unless world_discoverable?

      transfer_metadata
      publish_notify_on_success
    end

    private

    attr_reader :item

    def transfer_metadata
      transfer_to_document_store(DublinCoreService.new(item).ng_xml.to_xml(&:no_declaration), 'dc')
      %w(identityMetadata contentMetadata rightsMetadata).each do |stream|
        transfer_to_document_store(item.datastreams[stream].content.to_s, stream) if item.datastreams[stream]
      end
      transfer_to_document_store(PublicXmlService.new(item).to_xml, 'public')
      transfer_to_document_store(PublicDescMetadataService.new(item).to_xml, 'mods')
    end

    # Clear out the document cache for this item
    def unpublish
      purl_druid.prune!
      publish_delete_on_success
    end

    def world_discoverable?
      rights = item.rightsMetadata.ng_xml.clone.remove_namespaces!
      rights.at_xpath("//rightsMetadata/access[@type='discover']/machine/world")
    end

    # Create a file inside the content directory under the stacks.local_document_cache_root
    # @param [String] content The contents of the file to be created
    # @param [String] filename The name of the file to be created
    # @return [void]
    def transfer_to_document_store(content, filename)
      new_file = File.join(purl_druid.content_dir, filename)
      File.open(new_file, 'w') { |f| f.write content }
    end

    def purl_druid
      @purl_druid ||= DruidTools::PurlDruid.new item.pid, Config.stacks.local_document_cache_root
    end

    def prune_purl_dir
      purl_druid.prune!
    end

    ##
    # When publishing a PURL, we notify purl-fetcher of changes.
    # If the purl service isn't configured, instead we drop a `aa11bb2222` file into the `local_recent_changes` folder
    # to notify other applications watching the filesystem (i.e., purl-fetcher).
    # We also remove any .deletes entry that may have left over from a previous removal
    def publish_notify_on_success
      id = item.pid.gsub(/^druid:/, '')
      if Dor::Config.purl_services.url
        purl_services = Dor::Config.purl_services.rest_client
        purl_services["purls/#{id}"].post ''
      else
        Deprecation.warn(self, 'You have not configured perl-fetcher (Dor::Config.purl_services.url). This will result in an error in dor-services 7 ')
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

      id = item.pid.gsub(/^druid:/, '')

      purl_services = Dor::Config.purl_services.rest_client
      purl_services["purls/#{id}"].delete
    end
  end
end
