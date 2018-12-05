# frozen_string_literal: true

require 'moab'
module Sdr
  class Client
    class << self
      # @param [String] druid id of the object you want the version of
      # @return [Integer] the current version from SDR
      def current_version(druid)
        xml = client["objects/#{druid}/current_version"].get

        begin
          doc = Nokogiri::XML xml
          raise if doc.root.name != 'currentVersion'

          return Integer(doc.text)
        rescue StandardError
          raise "Unable to parse XML from SDR current_version API call: #{xml}"
        end
      end

      def client
        if Dor::Config.sdr.url
          # dor-services-app takes this path
          Dor::Config.sdr.rest_client
        elsif Dor::Config.dor_services.url
          # Anything that is not dor-servics-app should be through here.
          raise 'you are using dor-services to invoke calls to dor-services-app.  Use dor-services-client instead.'
        else
          raise Dor::ParameterError, 'Missing Dor::Config.sdr and/or Dor::Config.dor_services configuration'
        end
      end
    end
  end
end
