require 'confstruct/configuration'
require 'rsolr-ext'
require 'stomp'
require 'yaml'

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
      params = { :dor_services_url => result.dor_services.url }
      params[:timeout] = result.workflow.timeout if result.workflow.timeout
      Dor::WorkflowService.configure result.workflow.url, params
      return result
    end

    def autoconfigure(url, cert_file=Config.ssl.cert_file, key_file=Config.ssl.key_file, key_pass=Config.ssl.key_pass)
      client = make_rest_client(url, cert_file, key_file, key_pass)
      config = Confstruct::Configuration.symbolize_hash JSON.parse(client.get :accept => 'application/json')
      self.configure(config)
    end

    def sanitize
      self.dup
    end

    def make_rest_client(url, cert=Config.ssl.cert_file, key=Config.ssl.key_file, pass=Config.ssl.key_pass)
      params = {}
      params[:ssl_client_cert] = OpenSSL::X509::Certificate.new(File.read(cert)) if cert
      params[:ssl_client_key]  = OpenSSL::PKey::RSA.new(File.read(key), pass) if key
      RestClient::Resource.new(url, params)
    end

    def make_solr_connection(add_opts={})
      opts = Config.solrizer.opts.merge(add_opts).merge(
        :url => Config.solrizer.url
      )
      ::RSolr::Ext.connect(opts)
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
        :sdr => {
          :rest_client => Confstruct.deferred { |c| config.make_rest_client c.url },
        },
        :gsearch => {
          :rest_client => Confstruct.deferred { |c| config.make_rest_client c.rest_url },
          :client => Confstruct.deferred { |c| config.make_rest_client c.url }
        },
        :stomp => {
          :connection => Confstruct.deferred { |c| Stomp::Connection.new c.user, c.password, c.host, c.port, true, 5, { 'client-id' => c.client_id }},
          :client => Confstruct.deferred { |c| Stomp::Client.new c.user, c.password, c.host, c.port }
        }
      })
      true
    end

    set_callback :configure, :after do |config|
      config[:stomp][:host] ||= URI.parse(config.fedora.url).host rescue nil

      [:cert_file, :key_file, :key_pass].each do |key|
        stack = caller.dup
        stack.shift while stack[0] =~ %r{(active_support/callbacks|dor/config|dor-services)\.rb}
        if config.fedora[key].present?
          ActiveSupport::Deprecation.warn "Dor::Config -- fedora.#{key.to_s} is deprecated. Please use ssl.#{key.to_s} instead.", stack
          config.ssl[key] = config.fedora[key] unless config.ssl[key].present?
          config.fedora.delete(key)
        end
      end

      if ActiveFedora.respond_to?(:configurator)
        if config.solrizer.url.present?
          ActiveFedora::SolrService.register
          ActiveFedora::SolrService.instance.instance_variable_set :@conn, self.make_solr_connection
        end
      else
        ActiveFedora::RubydoraConnection.connect self.fedora_config if self.fedora.url.present?
        if self.solrizer.url.present?
          ActiveFedora::SolrService.register config.solrizer.url, config.solrizer.opts
          conn = ActiveFedora::SolrService.instance.conn.connection
          if config.ssl.cert_file.present?
            conn.use_ssl = true
            conn.cert = OpenSSL::X509::Certificate.new(File.read(config.ssl.cert_file))
            conn.key = OpenSSL::PKey::RSA.new(File.read(config.ssl.key_file),config.ssl.key_pass) if config.ssl.key_file.present?
            conn.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
        end
        ActiveFedora.init
        ActiveFedora.fedora_config_path = File.expand_path('../../../config/dummy.yml', __FILE__)
      end
    end

    # Act like an ActiveFedora.configurator

    def init *args; end

    def fedora_config
      fedora_uri = URI.parse(self.fedora.url)
      connection_opts = { :url => self.fedora.safeurl, :user => fedora_uri.user, :password => fedora_uri.password }
      connection_opts[:ssl_client_cert] = OpenSSL::X509::Certificate.new(File.read(self.ssl.cert_file)) if self.ssl.cert_file.present?
      connection_opts[:ssl_client_key] = OpenSSL::PKey::RSA.new(File.read(self.ssl.key_file),self.ssl.key_pass) if self.ssl.key_file.present?
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
  ActiveFedora.configurator = Config if ActiveFedora.respond_to?(:configurator)
end
