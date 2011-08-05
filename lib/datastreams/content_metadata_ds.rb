class ContentMetadataDS < ActiveFedora::NokogiriDatastream 
  
  def public_xml
    result = self.ng_xml.clone
    result.xpath('/contentMetadata/resource[not(file[(@deliver="yes" or @publish="yes")])]').each { |n| n.remove }
    result.xpath('/contentMetadata/resource/file[not(@deliver="yes" or @publish="yes")]').each { |n| n.remove }
    result.xpath('/contentMetadata/resource/file').xpath('@preserve|@shelve|@publish|@deliver').each { |n| n.remove }
    result.xpath('/contentMetadata/resource/file/checksum').each { |n| n.remove }
    result
  end
  
end
