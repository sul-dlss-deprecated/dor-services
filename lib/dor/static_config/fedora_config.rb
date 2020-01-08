# frozen_string_literal: true

require 'dor/certificate_authenticated_rest_resource_factory'

module Dor
  class StaticConfig
    # Represents the configuration for Fedora 3
    class FedoraConfig
      def initialize(hash)
        @url = hash.fetch(:url)
      end

      def configure(&block)
        instance_eval(&block)
      end

      def client
        CertificateAuthenticatedRestResourceFactory.create(url)
      end

      def url(new_value = nil)
        @url = new_value if new_value
        @url
      end

      # The url without the username or password
      def safeurl
        fedora_uri = URI.parse(url)
        fedora_uri.user = fedora_uri.password = nil
        fedora_uri.to_s
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
