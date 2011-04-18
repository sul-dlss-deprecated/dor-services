require 'nokogiri'
require 'rest-client'

handler = Class.new do
  def fetch(prefix, identifier)
    query = %{<?xml version="1.0" encoding="UTF-8"?>
  <query xmlns="http://exist.sourceforge.net/NS/exist">
      <text>
        declare namespace mods="http://www.loc.gov/mods/v3";
        /mods:mods[mods:identifier/text()="druid:#{identifier}"]
      </text>
  </query>}
    client = RestClient::Resource.new(Dor::Config[:exist_url])
    response = client['db/orbeon/fr/mods'].post(query, :content_type => 'application/xquery')
    doc = Nokogiri::XML(response)
    mods = doc.xpath('//mods:mods', { 'mods' => "http://www.loc.gov/mods/v3" })
    if mods.length > 0
      mods.first.to_s
    else
      nil
    end
  end

  def label(metadata)
    mods = Nokogiri::XML(metadata)
    mods.root.add_namespace_definition('mods','http://www.loc.gov/mods/v3')
    mods.xpath('/mods:mods/mods:titleInfo[1]').xpath('mods:title|mods:nonSort').collect { |n| n.text }.join(' ').strip
  end

  def prefixes
    ['mdtoolkit','druid']
  end
end

Dor::MetadataService.register(handler)