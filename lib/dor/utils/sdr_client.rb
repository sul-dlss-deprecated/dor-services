module Sdr
  module Client
    class << self

      # @param [String] druid id of the object you want the version of
      # @return [Integer] the current version from SDR
      def current_version(druid)
        sdr_client = Dor::Config.sdr.rest_client
        xml = sdr_client["objects/#{druid}/current_version"].get

        begin
          doc = Nokogiri::XML xml
          raise if doc.root.name != 'currentVersion'
          return Integer(doc.text)
        rescue
          raise "Unable to parse XML from SDR current_version API call: #{xml}"
        end
      end

    end
  end
end
