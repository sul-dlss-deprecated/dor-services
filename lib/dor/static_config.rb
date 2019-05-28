# frozen_string_literal: true

require 'rsolr'

module Dor
  # Provides configuration for dor-services
  class StaticConfig
    extend ActiveSupport::Autoload
    eager_autoload do
      autoload :CleanupConfig
      autoload :SslConfig
      autoload :FedoraConfig
      autoload :SolrConfig
      autoload :StacksConfig
      autoload :SuriConfig
      autoload :WorkflowConfig
    end

    def initialize(hash)
      @cleanup = CleanupConfig.new(hash.fetch(:cleanup))
      @ssl = SslConfig.new(hash.fetch(:ssl))
      @fedora = FedoraConfig.new(hash.fetch(:fedora))
      @solr = SolrConfig.new(hash.fetch(:solr))
      @stacks = StacksConfig.new(hash.fetch(:stacks))
      @suri = SuriConfig.new(hash.fetch(:suri))
      @workflow = WorkflowConfig.new(hash.fetch(:workflow))
    end

    def configure(&block)
      instance_eval(&block)
      maybe_connect_solr
    end

    def maybe_connect_solr
      return unless solr.url.present?

      ActiveFedora::SolrService.register
      ActiveFedora::SolrService.instance.instance_variable_set :@conn, make_solr_connection
    end

    def make_solr_connection
      ::RSolr.connect(url: Dor::Config.solr.url)
    end

    # This is consumed by ActiveFedora.configurator
    def solr_config
      { url: solr.url }
    end

    # This is consumed by ActiveFedora.configurator
    def fedora_config
      fedora_uri = URI.parse(fedora.url)
      connection_opts = { url: fedora.safeurl, user: fedora_uri.user, password: fedora_uri.password }
      connection_opts[:ssl_client_cert] = OpenSSL::X509::Certificate.new(File.read(ssl.cert_file)) if ssl.cert_file.present?
      connection_opts[:ssl_client_key] = OpenSSL::PKey::RSA.new(File.read(ssl.key_file), ssl.key_pass) if ssl.key_file.present?
      connection_opts[:ssl_cert_store] = default_ssl_cert_store
      connection_opts
    end

    # This is consumed by ActiveFedora.configurator
    def predicate_config
      # rubocop:disable Security/YAMLLoad
      YAML.load(File.read(File.expand_path('../../config/predicate_mappings.yml', __dir__)))
      # rubocop:enable Security/YAMLLoad
    end

    def default_ssl_cert_store
      @default_ssl_cert_store ||= RestClient::Request.default_ssl_cert_store
    end

    def cleanup
      @cleanup.configure(&block) if block_given?
      @cleanup
    end

    def ssl(&block)
      @ssl.configure(&block) if block_given?
      @ssl
    end

    def fedora(&block)
      @fedora.configure(&block) if block_given?
      @fedora
    end

    def solr(&block)
      @solr.configure(&block) if block_given?

      @solr
    end

    def stacks(&block)
      @stacks.configure(&block) if block_given?

      @stacks
    end

    def suri(&block)
      @suri.configure(&block) if block_given?

      @suri
    end

    def workflow(&block)
      @workflow.configure(&block) if block_given?

      @workflow
    end
  end
end
