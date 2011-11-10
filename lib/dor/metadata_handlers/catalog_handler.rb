require 'rest-client'

handler = Class.new do
  def fetch(prefix, identifier)
    client = RestClient::Resource.new(Dor::Config.metadata.catalog.url)
    client["?#{prefix.chomp}=#{identifier.chomp}"].get
  end

  def label(metadata)
    mods = Nokogiri::XML(metadata)
    mods.root.add_namespace_definition('mods','http://www.loc.gov/mods/v3')
    mods.xpath('/mods:mods/mods:titleInfo[1]').xpath('mods:title|mods:nonSort').collect { |n| n.text }.join(' ').strip
  end

  def prefixes
    ['catkey','barcode']
  end
end

Dor::MetadataService.register(handler)
