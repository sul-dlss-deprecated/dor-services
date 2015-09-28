require 'iiif/presentation'

module Dor
  module Presentable

    DC_NS = {'dc' => 'http://purl.org/dc/elements/1.1/', 'oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/'}

    def iiif_presentation_manifest_needed?(pub_obj_doc)
      if pub_obj_doc.at_xpath('/publicObject/contentMetadata[contains(@type,"image") or contains(@type,"map")]/resource[@type="image"]')
        return true
      elsif pub_obj_doc.at_xpath('/publicObject/contentMetadata[@type="book"]/resource[@type="page"]')
        return true
      else
        return false
      end
    end

    # Bypass this method if there are no image resources in contentMetadata
    def build_iiif_manifest(pub_obj_doc)
      id = pid.split(':').last

      lbl_node = pub_obj_doc.at_xpath '//oai_dc:dc/dc:title', DC_NS
      if lbl_node.nil?
        lbl_node = pub_obj_doc.at_xpath('/publicObject/identityMetadata/objectLabel')
      end
      raise 'Unable to build IIIF Presentation manifest:  No identityMetadata/objectLabel or dc:title' if lbl_node.nil?
      lbl = lbl_node.text

      purl_base_uri = "https://#{Dor::Config.stacks.document_cache_host}/#{id}"

      manifest_data = {
        '@id'   => "#{purl_base_uri}/iiif/manifest.json",
        'label' => lbl,
        'attribution' => 'Provided by the Stanford University Libraries',
        'logo' => {
          '@id' => 'https://stacks.stanford.edu/image/iiif/wy534zh7137%2FSULAIR_rosette/full/400,/0/default.jpg',
          'service' => {
            '@context' => 'http://iiif.io/api/image/2/context.json',
            '@id' => 'https://stacks.stanford.edu/image/iiif/wy534zh7137%2FSULAIR_rosette',
            'profile' => 'http://iiif.io/api/image/2/level1.json'
            }
          },
        'seeAlso' => {
          '@id' => "#{purl_base_uri}.mods",
          'format' => 'application/mods+xml'
        }
      }
      # Use the human copyright statement for attribution if present
      if (cr = pub_obj_doc.at_xpath('/publicObject/rightsMetadata/copyright/human[@type="copyright"]'))
        manifest_data['attribution'] = cr.text
      end

      manifest = IIIF::Presentation::Manifest.new manifest_data

      # Set viewingHint to paged if this is a book
      if pub_obj_doc.at_xpath('/publicObject/contentMetadata[@type="book"]')
        manifest.viewingHint = 'paged'
      end

      metadata = []
      # make into method, pass in xpath and label
      add_metadata 'Creator', '//oai_dc:dc/dc:creator', metadata, pub_obj_doc
      add_metadata 'Contributor', '//oai_dc:dc/dc:contributor', metadata, pub_obj_doc
      add_metadata 'Publisher', '//oai_dc:dc/dc:publisher', metadata, pub_obj_doc
      add_metadata 'Date', '//oai_dc:dc/dc:date', metadata, pub_obj_doc

      # Save off the first dc:description without displayLabel
      if (desc = pub_obj_doc.at_xpath('//oai_dc:dc/dc:description[not(@displayLabel)]', DC_NS))
        manifest.description = desc.text
      end

      manifest.metadata = metadata unless metadata.empty?

      seq_data = {
        '@id' => "#{purl_base_uri}/sequence-1",
        'label' => 'Current order'
      }
      sequence = IIIF::Presentation::Sequence.new seq_data

      # for each resource image, create a canvas
      count = 0
      pub_obj_doc.xpath('/publicObject/contentMetadata/resource[@type="image" or @type="page"]').each do |res_node|
        count += 1
        label_text = 'image'
        
        # if we have an external file for JP2000, build stack URLs to external resource images
        if res_node.at_xpath('externalFile[@mimetype="image/jp2"]')
          src_file_id = res_node.at_xpath('externalFile/@fileId').text.to_s
          src_item_id = res_node.at_xpath('externalFile/@objectId').text.to_s.split(':').last # child item
          src_image_data = res_node.at_xpath('externalFile/imageData')
        else
          src_file_id = res_node.at_xpath('file/@id').text
          src_item_id = id
          src_image_data = res_node.at_xpath('file/imageData')
        end
        label_node = res_node.at_xpath('label')
        label_text = label_node.text unless label_node.nil?
        
        img_file_name = src_file_id.split('.').first
        stacks_uri = "#{Dor::Config.stacks.url}/image/iiif/#{src_item_id}%2F#{img_file_name}"

        height = src_image_data['height'].to_i
        width = src_image_data['width'].to_i

        canv = IIIF::Presentation::Canvas.new
        canv['@id'] = "#{purl_base_uri}/canvas/canvas-#{count}"
        canv.label = label_text
        canv.height = height
        canv.width = width

        anno = IIIF::Presentation::Annotation.new
        anno['@id'] = "#{purl_base_uri}/imageanno/anno-#{count}"
        anno['on'] = canv['@id']

        img_res = IIIF::Presentation::ImageResource.new
        img_res['@id'] = "#{stacks_uri}/full/full/0/default.jpg"
        img_res.format = 'image/jpeg'
        img_res.height = height
        img_res.width = width

        svc = IIIF::Service.new ({
          '@context' => 'http://iiif.io/api/image/2/context.json',
          '@id' => stacks_uri,
          'profile' => Dor::Config.stacks.iiif_profile
        })

        # Use the first image to create a thumbnail on the manifest
        if count == 1
          thumb_sz = 400
          thumb = IIIF::Presentation::Resource.new
          thumb['@id'] = "#{stacks_uri}/full/#{thumb_sz},/0/default.jpg"
          thumb.service = svc
          manifest.thumbnail = thumb
        end

        img_res.service = svc
        anno.resource = img_res
        canv.images << anno
        sequence.canvases << canv
      end

      manifest.sequences << sequence
      manifest.to_json(:pretty => true)
    end

    def add_metadata(label, xpath, metadata, pub_obj_doc)
      nodes = pub_obj_doc.xpath xpath, DC_NS
      nodes.each do |node|
        h = {
          'label' => label,
          'value' => node.text
        }
        metadata << h
      end
    end

  end
end
