# frozen_string_literal: true

module Dor
  # Responsible for finding a path to a thumbnail based on the contentMetadata of an object
  class ThumbnailService
    # allow the mimetype attribute to be lower or camelcase when searching to make it more robust
    MIME_TYPE_FINDER = "@mimetype='image/jp2' or @mimeType='image/jp2'"

    # these are the finders we will use to search for a thumb resource in contentMetadata, they will be searched in the order provided, stopping when one is reached
    THUMB_XPATH_FINDERS = [
      # first find a file of mimetype jp2 explicitly marked as a thumb in the resource type and with a thumb=yes attribute
      { image_type: 'local', finder: "/contentMetadata/resource[@type='thumb' and @thumb='yes']/file[#{MIME_TYPE_FINDER}]" },
      # same thing for external files
      { image_type: 'external', finder: "/contentMetadata/resource[@type='thumb' and @thumb='yes']/externalFile[#{MIME_TYPE_FINDER}]" },
      # next find any image or page resource types with the thumb=yes attribute of mimetype jp2
      { image_type: 'local', finder: "/contentMetadata/resource[(@type='page' or @type='image') and @thumb='yes']/file[#{MIME_TYPE_FINDER}]" },
      # same thing for external file
      { image_type: 'external', finder: "/contentMetadata/resource[(@type='page' or @type='image') and @thumb='yes']/externalFile[#{MIME_TYPE_FINDER}]" },
      # next find a file of mimetype jp2 and resource type=thumb but not marked with the thumb directive
      { image_type: 'local', finder: "/contentMetadata/resource[@type='thumb']/file[#{MIME_TYPE_FINDER}]" },
      # same thing for external file
      { image_type: 'external', finder: "/contentMetadata/resource[@type='thumb']/externalFile[#{MIME_TYPE_FINDER}]" },
      # finally find the first page or image resource of mimetype jp2
      { image_type: 'local', finder: "/contentMetadata/resource[@type='page' or @type='image']/file[#{MIME_TYPE_FINDER}]" },
      # same thing for external file
      { image_type: 'external', finder: "/contentMetadata/resource[@type='page' or @type='image']/externalFile[#{MIME_TYPE_FINDER}]" }
    ].freeze

    # @params [Dor::Item] object
    def initialize(object)
      @object = object
    end

    attr_reader :object

    # @return [String] the computed thumb filename, with the druid prefix and a slash in front of it, e.g. oo000oo0001/filenamewith space.jp2
    def thumb
      return unless object.respond_to?(:contentMetadata) && object.contentMetadata.present?
      cm = object.contentMetadata.ng_xml
      thumb_image = nil

      THUMB_XPATH_FINDERS.each do |search_path|
        thumb_files = cm.xpath(search_path[:finder]) # look for a thumb
        next if thumb_files.empty?
        # if we find one, return the filename based on whether it is a local file or external file
        thumb_image = if search_path[:image_type] == 'local'
                        "#{object.remove_druid_prefix}/#{thumb_files[0]['id']}"
                      else
                        "#{object.remove_druid_prefix(thumb_files[0]['objectId'])}/#{thumb_files[0]['fileId']}"
                      end
        break # break out of the loop so we stop searching
      end

      thumb_image
    end
  end
end
