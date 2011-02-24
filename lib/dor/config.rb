require 'active_fedora'
require 'ostruct'

module Dor
  
  module Config
    
    @configuration ||= {
      :fedora_url => nil,
      :fedora_cert_file => nil,
      :fedora_key_file => nil,
      :fedora_key_pass => nil,
      :gsearch_solr_url => nil,
      :mint_suri_ids => false,
      :id_namespace => 'changeme',
      :suri_url => nil,
      :suri_user => nil,
      :suri_password => nil,
      :solr_url => nil
    }
    def @configuration.method_missing(sym,*args)
      property = sym.to_s.sub(/=$/,'').to_sym
      if self.has_key?(property)
        if sym.to_s =~ /=$/
          self[property] = args.first
        else
          self[property]
        end
      else 
        raise ::NameError, "Configuration key not found: #{property}"
      end
    end
    
    @fedora_instance = nil

    class << self
    
#      attr_reader :configuration
#      alias_method :config, :configuration

      def [](key)
        @configuration[key]
      end
 
      def []=(key,value)
        @configuration[key] = value
      end
      
      def configure
        fedora_config = repo_configuration_signature
        yield @configuration
        if fedora_config != repo_configuration_signature
          ::Fedora::Repository.register(@configuration.fedora_url)
          ::Fedora::Connection.const_set(:SSL_CLIENT_CERT_FILE,@configuration.fedora_cert_file)
          ::Fedora::Connection.const_set(:SSL_CLIENT_KEY_FILE,@configuration.fedora_key_file)
          ::Fedora::Connection.const_set(:SSL_CLIENT_KEY_PASS,@configuration.fedora_key_pass)
        end
      end

      private
      def repo_configuration_signature
        @configuration.values_at(:fedora_url,:fedora_cert_file,:fedora_key_file,:fedora_key_pass).collect { |v| v.to_s }.join('::')
      end

    end
    
  end
  
end