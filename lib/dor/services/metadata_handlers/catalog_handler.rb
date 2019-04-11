# frozen_string_literal: true

require 'rest-client'

module Dor
  class CatalogHandler
    def fetch(prefix, identifier)
      client = RestClient::Resource.new(Dor::Config.metadata.catalog.url,
                                        Dor::Config.metadata.catalog.user,
                                        Dor::Config.metadata.catalog.pass)
      params = "?#{prefix.chomp}=#{identifier.chomp}"
      client[params].get
    rescue RestClient::Exception => e
      raise BadResponseFromCatalog, "#{e.class} - when contacting (with BasicAuth hidden): #{Dor::Config.metadata.catalog.url}#{params}"
    end

    def label(metadata)
      mods = Nokogiri::XML(metadata)
      mods.root.add_namespace_definition('mods', 'http://www.loc.gov/mods/v3')
      mods.xpath('/mods:mods/mods:titleInfo[1]').xpath('mods:title|mods:nonSort').collect(&:text).join(' ').strip
    end

    def prefixes
      %w(catkey barcode)
    end
  end
end
