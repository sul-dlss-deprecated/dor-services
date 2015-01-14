require 'iiif/presentation'

module Dor
  module Presentable

    def iiif_presentation_manifest_needed? pub_obj_doc
      if(pub_obj_doc.at_xpath('/publicObject/contentMetadata[@type="image"]/resource[@type="image"]'))
        return true
      elsif(pub_obj_doc.at_xpath('/publicObject/contentMetadata[@type="book"]/resource[@type="page"]'))
        return true
      else
        return false
      end
    end

    # Bypass this method if there are no image resources in contentMetadata
    def build_iiif_manifest pub_obj_doc
      id = self.pid.split(':').last
      lbl = pub_obj_doc.at_xpath('/publicObject/identityMetadata/objectLabel').text  # TODO what if no label?
      purl_base_uri = "http://#{Dor::Config.stacks.document_cache_host}/#{id}"


      manifest_data = {
        '@id'   => "#{purl_base_uri}/manifest",
        'label' => lbl,
        'attribution' => 'Provided by the Stanford University Libraries',
        'seeAlso' => {
          '@id' => "#{purl_base_uri}.mods",
          'format' => 'application/mods+xml'
        }
      }
      manifest = IIIF::Presentation::Manifest.new manifest_data

      seq_data = {
        '@id' => "#{purl_base_uri}/sequence",
        'label' => 'Current order'
      }
      sequence = IIIF::Presentation::Sequence.new seq_data

      # for each resource image, create a canvas
      count = 0
      # TODO inner loop for each file within a resource?

      pub_obj_doc.xpath('/publicObject/contentMetadata/resource[@type="image" or @type="page"]').each do |res_node|
        count += 1
        img_file_name = res_node.at_xpath('file/@id').text.split('.').first
        height = res_node.at_xpath('file/imageData/@height').text.to_i
        width = res_node.at_xpath('file/imageData/@width').text.to_i
        stacks_uri = "#{Dor::Config.stacks.url}/image/iiif/#{id}%2F#{img_file_name}"
        # create canvas
        #        (for each image create anno then resource?)
        #        annotation
        #        ImageResource
        canv = IIIF::Presentation::Canvas.new
        canv['@id'] = "#{purl_base_uri}/canvas/canvas-#{count}"
        canv.label = res_node.at_xpath('label').text
        canv.height = height
        canv.width = width

        anno = IIIF::Presentation::Annotation.new
        anno['@id'] = "#{purl_base_uri}/imageanno/anno-#{count}"
        anno['on'] = canv['@id']

        img_res = IIIF::Presentation::ImageResource.new
        img_res['@id'] = stacks_uri
        img_res.format = res_node.at_xpath('file/@mimetype').text
        img_res.height = height
        img_res.width = width

        svc = IIIF::Service.new ({
          '@id' => stacks_uri,
          'profile' => Dor::Config.stacks.iiif_profile
        })

        img_res.service = svc
        anno.resource = img_res
        canv.images << anno
        sequence.canvases << canv
      end

      manifest.sequences << sequence
      manifest.to_json(:pretty => true)
    end
  end
end
