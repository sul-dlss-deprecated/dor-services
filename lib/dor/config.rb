require 'confstruct/configuration'
require 'rsolr-ext'
require 'rsolr/client_cert'

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

    def make_solr_connection(add_opts={})
      opts = Config.solrizer.opts.merge(add_opts).merge(
        :url => Config.solrizer.url,
        :ssl_cert_file => Config.fedora.cert_file, :ssl_key_file => Config.fedora.key_file, :ssl_key_pass => Config.fedora.key_pass
      )
      ::RSolr::ClientCert.connect(opts).extend(RSolr::Ext::Client)
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
      ActiveFedora.init
      if config.solrizer.url.present?
        ActiveFedora::SolrService.register
        ActiveFedora::SolrService.instance.instance_variable_set :@conn, self.make_solr_connection
      end
    end

    # Act like an ActiveFedora.configurator

    def init *args; end
    
    def fedora_config
      fedora_uri = URI.parse(self.fedora.url)
      connection_opts = { :url => self.fedora.safeurl, :user => fedora_uri.user, :password => fedora_uri.password }
      connection_opts[:ssl_client_cert] = OpenSSL::X509::Certificate.new(File.read(self.fedora.cert_file)) if self.fedora.cert_file.present?
      connection_opts[:ssl_client_key] = OpenSSL::PKey::RSA.new(File.read(self.fedora.key_file),self.fedora.key_pass) if self.fedora.key_file.present?
      connection_opts
    end
    
    def solr_config
      { :url => self.solrizer.url }
    end
    
    def predicate_config
      YAML.load(File.read(File.expand_path('../../../config/predicate_mappings.yml',__FILE__)))
    end
  end

  Config = Configuration.new(YAML.load(File.read(File.expand_path('../../../config/config_defaults.yml', __FILE__))))
  ActiveFedora.configurator = Config
end
