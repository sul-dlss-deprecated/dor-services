require 'confstruct/configuration'
require 'rsolr'
require 'yaml'
require 'dor/certificate_authenticated_rest_resource_factory'

module Dor
  class Configuration < Confstruct::Configuration
    include ActiveSupport::Callbacks
    define_callbacks :initialize
    define_callbacks :configure

    def initialize(*args)
      super *args
      run_callbacks(:initialize) { }
    end

    # Call the super method with callbacks and with $VERBOSE temporarily disabled
    def configure(*args)
      result = self
      temp_verbose = $VERBOSE
      $VERBOSE = nil
      begin
        run_callbacks :configure do
          result = super(*args)
        end
      ensure
        $VERBOSE = temp_verbose
      end
      result
    end

    def autoconfigure(url, cert_file = Config.ssl.cert_file, key_file = Config.ssl.key_file, key_pass = Config.ssl.key_pass)
      client = make_rest_client(url, cert_file, key_file, key_pass)
      config = Confstruct::Configuration.symbolize_hash JSON.parse(client.get(accept: 'application/json'))
      configure(config)
    end
    deprecation_deprecate :autoconfigure

    def sanitize
      dup
    end

    def make_rest_client(url, cert = Config.ssl.cert_file, key = Config.ssl.key_file, pass = Config.ssl.key_pass)
      params = {}
      params[:ssl_client_cert] = OpenSSL::X509::Certificate.new(File.read(cert)) if cert
      params[:ssl_client_key]  = OpenSSL::PKey::RSA.new(File.read(key), pass) if key
      RestClient::Resource.new(url, params)
    end
    deprecation_deprecate :make_rest_client


    def make_solr_connection(add_opts = {})
      opts = Dor::Config.solr.opts.merge(add_opts).merge(
        :url => Dor::Config.solr.url
      )
      ::RSolr.connect(opts)
    end

    set_callback :initialize, :after do |config|
      config.deep_merge!({
        :fedora => {
          :client => Confstruct.deferred { |c| CertificateAuthenticatedRestResourceFactory.create(:fedora) },
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
        :dor_services => {
          :rest_client => Confstruct.deferred { |c| RestResourceFactory.create(:dor_services) }
        },
        :sdr => {
          :rest_client => Confstruct.deferred { |c| RestResourceFactory.create(:sdr) }
        },
        :workflow => {
          :client => Confstruct.deferred do |c|
            Dor::WorkflowService.configure c.url, logger: c.client_logger, timeout: c.timeout, dor_services_url: config.dor_services.url
            Dor::WorkflowService
          end,
          :client_logger => Confstruct.deferred do |c|
            if c.logfile && c.shift_age
              Logger.new(c.logfile, c.shift_age)
            elsif c.logfile
              Logger.new(c.logfile)
            end
          end
        }
      })
      true
    end

    set_callback :configure, :after do |config|
      # Deprecate fedora.cert_file, fedora.key_file, fedora.key_pass
      [:cert_file, :key_file, :key_pass].each do |key|
        next unless config.fedora[key].present?
        stack = Kernel.caller.dup
        stack.shift while stack[0] =~ %r{(active_support/callbacks|dor/config|dor-services)\.rb}
        ActiveSupport::Deprecation.warn "Dor::Config -- fedora.#{key} is deprecated. Please use ssl.#{key} instead.", stack
        config.ssl[key] = config.fedora[key] unless config.ssl[key].present?
        config.fedora.delete(key)
      end

      if config.solrizer.present?
        stack = Kernel.caller.dup
        stack.shift while stack[0] =~ %r{(active_support/callbacks|dor/config|dor-services)\.rb}
        ActiveSupport::Deprecation.warn "Dor::Config -- solrizer configuration is deprecated. Please use solr instead.", stack

        config.solrizer.each do |k, v|
          config.solr[k] ||= v
        end
      end

      if config.solr.url.present?
        ActiveFedora::SolrService.register
        ActiveFedora::SolrService.instance.instance_variable_set :@conn, make_solr_connection
      end
    end

    # Act like an ActiveFedora.configurator

    def init(*args); end

    def fedora_config
      fedora_uri = URI.parse(fedora.url)
      connection_opts = { :url => fedora.safeurl, :user => fedora_uri.user, :password => fedora_uri.password }
      connection_opts[:ssl_client_cert] = OpenSSL::X509::Certificate.new(File.read(ssl.cert_file)) if ssl.cert_file.present?
      connection_opts[:ssl_client_key] = OpenSSL::PKey::RSA.new(File.read(ssl.key_file), ssl.key_pass) if ssl.key_file.present?
      connection_opts[:ssl_cert_store] = default_ssl_cert_store
      connection_opts
    end

    def solr_config
      { :url => solr.url }
    end

    def predicate_config
      YAML.load(File.read(File.expand_path('../../../config/predicate_mappings.yml', __FILE__)))
    end

    def default_ssl_cert_store
      @default_ssl_cert_store ||= RestClient::Request.default_ssl_cert_store
    end
  end

  Config = Configuration.new(YAML.load(File.read(File.expand_path('../../../config/config_defaults.yml', __FILE__))))
  ActiveFedora.configurator = Config
end
