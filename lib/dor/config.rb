require 'confstruct/configuration'

module Dor
  class Configuration < Confstruct::Configuration
    def define_dynamic_fields!
      self.deep_merge!({
        :fedora => {
          :client => Confstruct.deferred { |c| self.make_rest_client c.url },
          :safeurl => Confstruct.deferred { |c|
            begin
              fedora_uri = URI.parse(self.fedora.url)
              fedora_uri.user = fedora_uri.password = nil
              fedora_uri.to_s
            rescue URI::InvalidURIError
              nil
            end
          }
        },
        :gsearch => {
          :rest_client => Confstruct.deferred { |c| self.make_rest_client c.rest_url },
          :client => Confstruct.deferred { |c| self.make_rest_client c.url }
        }
      })
      self
    end
    
    def configure *args, &block
      super *args, &block
      register_fedora(self.fedora)
    end
    
    def after_config! config
      temp_v = $-v
      $-v = nil
      begin
        Object.const_set(:ENABLE_SOLR_UPDATES,false)
        ::Fedora::Repository.register(config.fedora.url)
        ::Fedora::Connection.const_set(:SSL_CLIENT_CERT_FILE,config.fedora.cert_file)
        ::Fedora::Connection.const_set(:SSL_CLIENT_KEY_FILE,config.fedora.key_file)
        ::Fedora::Connection.const_set(:SSL_CLIENT_KEY_PASS,config.fedora.key_pass)
      ensure
        $-v = temp_v
      end
      true
    end

    def make_rest_client(url, cert=Config.fedora.cert_file, key=Config.fedora.key_file, pass=Config.fedora.key_pass)
      params = {}
      params[:ssl_client_cert] = OpenSSL::X509::Certificate.new(File.read(cert)) if cert
      params[:ssl_client_key]  = OpenSSL::PKey::RSA.new(File.read(key), pass) if key
      RestClient::Resource.new(url, params)
    end
  end

  Config = Configuration.new(YAML.load(File.read(File.expand_path('../config_defaults.yml', __FILE__)))).define_dynamic_fields!
end

