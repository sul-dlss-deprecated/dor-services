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
    
    def after_config! config
      temp_v = $-v
      $-v = nil
      begin
        fedora_uri = URI.parse(config.fedora.url)
        ActiveFedora::RubydoraConnection.connect :url => config.fedora.safeurl, 
          :user => fedora_uri.user, :password => fedora_uri.password, 
          :ssl_client_cert => OpenSSL::X509::Certificate.new(File.read(config.fedora.cert_file)), 
          :ssl_client_key => OpenSSL::PKey::RSA.new(File.read(config.fedora.key_file),config.fedora.key_pass)

        ActiveFedora::SolrService.register config.solrizer.url, config.solrizer.opts
        conn = ActiveFedora::SolrService.instance.conn.connection
        conn.use_ssl = true
        conn.cert = OpenSSL::X509::Certificate.new(File.read(config.fedora.cert_file))
        conn.key = OpenSSL::PKey::RSA.new(File.read(config.fedora.key_file),config.fedora.key_pass)
        conn.verify_mode = OpenSSL::SSL::VERIFY_NONE
        ActiveFedora.fedora_config_path ||= File.expand_path('../../../config/dummy.yml', __FILE__)
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

  Config = Configuration.new(YAML.load(File.read(File.expand_path('../../../config/config_defaults.yml', __FILE__)))).define_dynamic_fields!
end

