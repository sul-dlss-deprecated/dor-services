require 'json'
require 'active_support/core_ext'

module Dor
  
  class SearchService

    RISEARCH_TEMPLATE = "select $object from <#ri> where $object <dc:identifier> '%s'"
    @@index_version = nil
    
    Config.declare(:gsearch) { 
      rest_url nil
      url nil 
      instance_eval do
        def rest_client
          RestClient::Resource.new(
            self.rest_url,
            :ssl_client_cert  =>  OpenSSL::X509::Certificate.new(File.read(Config.fedora.cert_file)),
            :ssl_client_key   =>  OpenSSL::PKey::RSA.new(File.read(Config.fedora.key_file), Config.fedora.key_pass)
          )
        end

        def client
          RestClient::Resource.new(
            self.url,
            :ssl_client_cert  =>  OpenSSL::X509::Certificate.new(File.read(Config.fedora.cert_file)),
            :ssl_client_key   =>  OpenSSL::PKey::RSA.new(File.read(Config.fedora.key_file), Config.fedora.key_pass)
          )
        end
      end
    }
    
    class << self
      
      def index_version
        if @@index_version.nil?
          xsl_doc = Nokogiri::XML(File.read(File.expand_path('../../gsearch/demoFoxmlToSolr.xslt',__FILE__)))
          @@index_version = xsl_doc.at_xpath('/xsl:stylesheet/xsl:variable[@name="INDEXVERSION"]/text()').to_s
        end
        @@index_version
      end
      
      def reindex(*pids)
        client = Config.gsearch.rest_client
        pids.in_groups_of(20, false) do |group|
          group.each { |pid| client["?operation=updateIndex&action=fromPid&value=#{pid}"].get }
          yield group if block_given?
        end
        pids
      end

      def risearch(query, opts = {})
        client = Config.fedora.client['risearch']
        client.options[:timeout] = opts.delete(:timeout)
        query_params = {
          :type => 'tuples',
          :lang => 'itql',
          :format => 'CSV',
          :limit => '1000',
          :stream => 'on',
          :query => query
        }.merge(opts)
        result = client.post(query_params)
        result.split(/\n/)[1..-1].collect { |pid| pid.chomp.sub(/^info:fedora\//,'') }
      end
      
      def gsearch(params)
        client = Config.gsearch.client
        query_params = params.merge(:wt => 'json')
        query_string = query_params.collect { |k,v| 
          if v.is_a?(Array)
            v.collect { |vv| "#{k}=#{URI.encode(vv.to_s)}" }.join('&')
          else
            "#{k}=#{URI.encode(v.to_s)}" 
          end
        }.join('&')
        puts client["select?#{query_string}"].to_s
        result = JSON.parse(client["select?#{query_string}"].get)
      end
      
      def query_by_id(id)
        if id.is_a?(Hash) # Single valued: { :google => 'STANFORD_0123456789' }
          id = id.collect { |*v| v.join(':') }.first
        elsif id.is_a?(Array) # Two values: [ 'google', 'STANFORD_0123456789' ]
          id = id.join(':')
        end
        self.risearch(RISEARCH_TEMPLATE % id)
      end

    end
    
  end
  
end