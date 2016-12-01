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
      release_xml = Nokogiri(generate_release_xml)

      im = object.datastreams['identityMetadata'].ng_xml.clone
      im.search('//release').each(&:remove) # remove any <release> tags from public xml which have full history

      pub.add_child(im.root) # add in modified identityMetadata datastream
      public_content_metadata = object.datastreams['contentMetadata'].public_xml
      pub.add_child(public_content_metadata.root.clone) if public_content_metadata.xpath('//resource').any?
      pub.add_child(object.datastreams['rightsMetadata'].ng_xml.root.clone)

      rels = object.public_relationships.root
      pub.add_child(rels.clone) unless rels.nil? # TODO: Should never be nil in practice; working around an ActiveFedora quirk for testing
      pub.add_child(object.generate_dublin_core.root.clone)
      pub.add_child(Nokogiri::XML(object.generate_public_desc_md).root.clone)
      pub.add_child(release_xml.root.clone) unless release_xml.xpath('//release').children.size == 0 # If there are no release_tags, this prevents an empty <releaseData/> from being added
      # Note we cannot base this on if an individual object has release tags or not, because the collection may cause one to be generated for an item,
      # so we need to calculate it and then look at the final result.s
      pub.add_child(Nokogiri("<thumb>#{object.thumb}</thumb>").root.clone) unless object.thumb.nil?

      new_pub = Nokogiri::XML(pub.to_xml) { |x| x.noblanks }
      new_pub.encoding = 'UTF-8'
      new_pub.to_xml
    end
    

    # Generate XML structure for inclusion to Purl
    # @return [String] The XML release node as a string, with ReleaseDigest as the root document
    def generate_release_xml
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.releaseData {
          object.released_for.each do |project, released_value|
            xml.release(released_value['release'], :to => project)
          end
        }
      end
      builder.to_xml
    end
  end
end
