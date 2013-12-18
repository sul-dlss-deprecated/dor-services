require 'nokogiri'
require 'rest-client'

handler = Class.new do
  def fetch(prefix, identifier)
    if prefixes.has_value?(prefix)
      response = RestClient.get "#{Dor::Config.geonetwork.service_root}/srv/eng/xml.metadata.get", 
        :params => { :uuid => identifier }
      doc = Nokogiri::XML(response)
      result = doc.xpath('//gmd:MD_Metadata').first
      result.xpath('//geonet:info') {|e| e.remove }
      result.nil? ? nil : result.to_xml(:indent => 2, :encoding => 'UTF-8')
    else
      nil
    end
  end
  
  def label(metadata)
    xml = Nokogiri::XML(metadata)
    if xml.root.nil?
      return ""
    end
    if xml.root.name == 'MD_Metadata' 
      xml.xpath("gmd:identificationInfo/gmd:MD_DataIdentification/" + 
                "gmd:citation/gmd:CI_Citation/" + 
                "gmd:title/gco:CharacterString").text
    else
      raise ArgumentError, "metadata is not ISO19139: #{xml.root.name}"
    end
  end

  def prefixes
    ['geomdtk', 'geonetwork']
  end
end

Dor::MetadataService.register(handler)
