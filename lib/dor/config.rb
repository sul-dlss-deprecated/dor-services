require 'mod_cons'

module Dor
  Config = ModCons::Configuration.new(:'Dor::Config')

  Config.declare do
    fedora do
      url nil
      safeurl nil
      cert_file nil
      key_file nil
      key_pass ''

      instance_eval do
        def client
          RestClient::Resource.new(
            self.url,
            :ssl_client_cert  =>  OpenSSL::X509::Certificate.new(File.read(self.cert_file)),
            :ssl_client_key   =>  OpenSSL::PKey::RSA.new(File.read(self.key_file), self.key_pass)
          )
        end
      end

      config_changed do |fedora|
        fedora_uri = URI.parse(fedora.url)
        fedora_uri.user = fedora_uri.password = nil
        fedora.safeurl fedora_uri.to_s
        
        temp_v = $-v
        $-v = nil
        begin
          if Object.const_defined? :Fedora
            ::ENABLE_SOLR_UPDATES = false
            ::Fedora::Repository.register(fedora.url)
            ::Fedora::Connection.const_set(:SSL_CLIENT_CERT_FILE,fedora.cert_file)
            ::Fedora::Connection.const_set(:SSL_CLIENT_KEY_FILE,fedora.key_file)
            ::Fedora::Connection.const_set(:SSL_CLIENT_KEY_PASS,fedora.key_pass)
          else
            
          end
        ensure
         $-v = temp_v
        end
      end
    end
  end
    
end

