require 'nokogiri'
require 'rest-client'

handler = Class.new do
  Dor::Config.metadata.declare(:exist) { url nil }
  
  def fetch(prefix, identifier)
    query = <<-QUERY
<?xml version="1.0" encoding="UTF-8"?>
<query xmlns="http://exist.sourceforge.net/NS/exist">
    <text>
      declare namespace mods="http://www.loc.gov/mods/v3";
      declare variable $identifier as xs:string := "druid:#{identifier}";
      /mods:mods[mods:identifier=$identifier] | /msDesc[msIdentifier/idno=$identifier]
    </text>
</query>
    QUERY
    client = RestClient::Resource.new(Dor::Config.metadata.exist.url)
    response = client['db/orbeon/fr'].post(query, :content_type => 'application/xquery')
    doc = Nokogiri::XML(response)
    doc.root.add_namespace_definition('exist','http://exist.sourceforge.net/NS/exist')
    result = doc.xpath('/exist:result/*[1]').first
    result.nil? ? nil : result.to_s
  end

  def label(metadata)
    xml = Nokogiri::XML(metadata)
    if xml.root.nil?
      return ""
    end
    case xml.root.name
    when 'msDesc' then xml.xpath('/msDesc/msIdentifier/collection').text
    when 'mods'   then 
      xml.root.add_namespace_definition('mods','http://www.loc.gov/mods/v3')
      xml.xpath('/mods:mods/mods:titleInfo[1]').xpath('mods:title|mods:nonSort').collect { |n| n.text }.join(' ').strip
    end
  end

  def prefixes
    ['mdtoolkit','druid']
  end
end

Dor::MetadataService.register(handler)