require 'dor/rest_resource_factory'
# Creates RestClient::Resources with client ssl keys for various connections
module Dor
  class CertificateAuthenticatedRestResourceFactory < RestResourceFactory

    private

    # @return [Hash] options for creating a RestClient::Resource
    def connection_options
      params = super
      params[:ssl_client_cert] = cert if cert
      params[:ssl_client_key]  = key if key
      params
    end

    # @return [OpenSSL::X509::Certificate]
    def cert
      @cert ||= OpenSSL::X509::Certificate.new(File.read(cert_file)) if cert_file
    end

    def cert_file
      Dor::Config.ssl.cert_file
    end

    def key_file
      Dor::Config.ssl.key_file
    end

    def key_pass
      Dor::Config.ssl.key_pass
    end

    # @return [OpenSSL::PKey::RSA]
    def key
      @key ||= OpenSSL::PKey::RSA.new(File.read(key_file), key_pass) if key_file
    end
  end
end
