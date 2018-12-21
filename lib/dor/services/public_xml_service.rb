# frozen_string_literal: true

module Dor
  class PublicXmlService
    attr_reader :object

    def initialize(object)
      @object = object
    end

    def to_xml
      pub = Nokogiri::XML('<publicObject/>').root
      pub['id'] = object.pid
      pub['published'] = Time.now.utc.xmlschema
      pub['publishVersion'] = 'dor-services/' + Dor::VERSION

      pub.add_child(public_identity_metadata.root) # add in modified identityMetadata datastream
      pub.add_child(public_content_metadata.root) if public_content_metadata.xpath('//resource').any?
      pub.add_child(public_rights_metadata.root)

      pub.add_child(public_relationships.root) unless public_relationships.nil? # TODO: Should never be nil in practice; working around an ActiveFedora quirk for testing
      pub.add_child(DublinCoreService.new(object).ng_xml.root)
      pub.add_child(PublicDescMetadataService.new(object).ng_xml.root)
      pub.add_child(release_xml.root) unless release_xml.xpath('//release').children.size == 0 # If there are no release_tags, this prevents an empty <releaseData/> from being added
      # Note we cannot base this on if an individual object has release tags or not, because the collection may cause one to be generated for an item,
      # so we need to calculate it and then look at the final result.

      thumb = ThumbnailService.new(object).thumb
      pub.add_child(Nokogiri("<thumb>#{thumb}</thumb>").root) unless thumb.nil?

      new_pub = Nokogiri::XML(pub.to_xml, &:noblanks)
      new_pub.encoding = 'UTF-8'
      new_pub.to_xml
    end

    # Generate XML structure for inclusion to Purl
    # @return [String] The XML release node as a string, with ReleaseDigest as the root document
    def release_xml
      @release_xml ||= begin
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.releaseData do
            object.released_for.each do |project, released_value|
              xml.release(released_value['release'], to: project)
            end
          end
        end
        Nokogiri::XML(builder.to_xml)
      end
    end

    def public_relationships
      @public_relationships ||= object.public_relationships.clone
    end

    def public_rights_metadata
      @public_rights_metadata ||= object.datastreams['rightsMetadata'].ng_xml.clone
    end

    def public_identity_metadata
      @public_identity_metadata ||= begin
        im = object.datastreams['identityMetadata'].ng_xml.clone
        im.search('//release').each(&:remove) # remove any <release> tags from public xml which have full history
        im
      end
    end

    # @return [Nokogiri::XML::Document] sanitized for public consumption
    def public_content_metadata
      return Nokogiri::XML::Document.new unless object.datastreams['contentMetadata']

      @public_content_metadata ||= begin
        result = object.datastreams['contentMetadata'].ng_xml.clone

        # remove any resources or attributes that are not destined for the public XML
        result.xpath('/contentMetadata/resource[not(file[(@deliver="yes" or @publish="yes")]|externalFile)]').each(&:remove)
        result.xpath('/contentMetadata/resource/file[not(@deliver="yes" or @publish="yes")]').each(&:remove)
        result.xpath('/contentMetadata/resource/file').xpath('@preserve|@shelve|@publish|@deliver').each(&:remove)
        result.xpath('/contentMetadata/resource/file/checksum').each(&:remove)

        # support for dereferencing links via externalFile element(s) to the source (child) item - see JUMBO-19
        result.xpath('/contentMetadata/resource/externalFile').each do |externalFile|
          # enforce pre-conditions that resourceId, objectId, fileId are required
          src_resource_id = externalFile['resourceId']
          src_druid = externalFile['objectId']
          src_file_id = externalFile['fileId']
          raise ArgumentError, "Malformed externalFile data: #{externalFile.inspect}" if [src_resource_id, src_file_id, src_druid].map(&:blank?).any?

          # grab source item
          src_item = Dor.find(src_druid)

          # locate and extract the resourceId/fileId elements
          doc = src_item.datastreams['contentMetadata'].ng_xml
          src_resource = doc.at_xpath("//resource[@id=\"#{src_resource_id}\"]")
          src_file = src_resource.at_xpath("file[@id=\"#{src_file_id}\"]")
          src_image_data = src_file.at_xpath('imageData')

          # always use title regardless of whether a child label is present
          src_label = doc.create_element('label')
          src_label.content = src_item.full_title

          # add the extracted label and imageData
          externalFile.add_previous_sibling(src_label)
          externalFile << src_image_data unless src_image_data.nil?
        end

        result
      end
    end
  end
end
