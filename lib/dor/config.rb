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
      :suri_pass => nil,
      :solr_url => nil,
      :workflow_url => nil
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

    class << self
    
#      attr_reader :configuration
#      alias_method :config, :configuration

      def [](key)
        @configuration[key]
      end
 
      def []=(key,value)
        @configuration[key] = value
      end
      
      def to_hash
        @configuration.dup
      end
      
      def configure(hash = {})
        fedora_config = repo_configuration_signature
        @configuration.merge!(hash.reject { |k,v| @configuration.has_key?(k) == false })
        yield @configuration if block_given?
        if fedora_config != repo_configuration_signature
          temp_v = $-v
          $-v = nil
          begin
            ::Fedora::Repository.register(@configuration.fedora_url)
            ::Fedora::Connection.const_set(:SSL_CLIENT_CERT_FILE,@configuration.fedora_cert_file)
            ::Fedora::Connection.const_set(:SSL_CLIENT_KEY_FILE,@configuration.fedora_key_file)
            ::Fedora::Connection.const_set(:SSL_CLIENT_KEY_PASS,@configuration.fedora_key_pass)
          ensure
            $-v = temp_v
          end
        end
      end

      private
      def repo_configuration_signature
        @configuration.values_at(:fedora_url,:fedora_cert_file,:fedora_key_file,:fedora_key_pass).collect { |v| v.to_s }.join('::')
      end

    end
    
  end
  
end