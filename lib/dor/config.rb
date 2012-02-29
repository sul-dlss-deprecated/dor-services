require 'confstruct/configuration'

module Dor
  class Configuration < Confstruct::Configuration
    include ActiveSupport::Callbacks
    define_callbacks :initialize
    define_callbacks :configure
    
    def initialize *args
      super *args
      run_callbacks(:initialize) { }
    end
    
    def configure *args
      result = self
      temp_v = $-v
      $-v = nil
      begin
        run_callbacks :configure do
          result = super(*args)
        end
      ensure
        $-v = temp_v
      end
      return result
    end
    
    def make_rest_client(url, cert=Config.fedora.cert_file, key=Config.fedora.key_file, pass=Config.fedora.key_pass)
      params = {}
      params[:ssl_client_cert] = OpenSSL::X509::Certificate.new(File.read(cert)) if cert
      params[:ssl_client_key]  = OpenSSL::PKey::RSA.new(File.read(key), pass) if key
      RestClient::Resource.new(url, params)
    end

    set_callback :initialize, :after do |config|
      config.deep_merge!({
        :fedora => {
          :client => Confstruct.deferred { |c| config.make_rest_client c.url },
          :safeurl => Confstruct.deferred { |c|
            begin
              fedora_uri = URI.parse(config.fedora.url)
              fedora_uri.user = fedora_uri.password = nil
              fedora_uri.to_s
            rescue URI::InvalidURIError
              nil
            end
          }
        },
        :gsearch => {
          :rest_client => Confstruct.deferred { |c| config.make_rest_client c.rest_url },
          :client => Confstruct.deferred { |c| config.make_rest_client c.url }
        }
      })
      true
    end

    set_callback :configure, :after do |config|
      fedora_uri = URI.parse(config.fedora.url)
      connection_opts = { :url => config.fedora.safeurl, :user => fedora_uri.user, :password => fedora_uri.password }
      connection_opts[:ssl_client_cert] = OpenSSL::X509::Certificate.new(File.read(config.fedora.cert_file)) if config.fedora.cert_file.present?
      connection_opts[:ssl_client_key] = OpenSSL::PKey::RSA.new(File.read(config.fedora.key_file),config.fedora.key_pass) if config.fedora.key_file.present?
      ActiveFedora::RubydoraConnection.connect connection_opts

      if config.solrizer.url.present?
        ActiveFedora::SolrService.register config.solrizer.url, config.solrizer.opts
        conn = ActiveFedora::SolrService.instance.conn.connection
        if config.fedora.cert_file.present?
          conn.use_ssl = true
          conn.cert = OpenSSL::X509::Certificate.new(File.read(config.fedora.cert_file))
          conn.key = OpenSSL::PKey::RSA.new(File.read(config.fedora.key_file),config.fedora.key_pass) if config.fedora.key_file.present?
          conn.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end

      ActiveFedora.fedora_config_path ||= File.expand_path('../../../config/dummy.yml', __FILE__)
      true
    end
  end

  Config = Configuration.new(YAML.load(File.read(File.expand_path('../../../config/config_defaults.yml', __FILE__))))
end

