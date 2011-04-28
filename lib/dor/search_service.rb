require 'json'

module Dor
  
  class SearchService

    RISEARCH_TEMPLATE = "select $object from <#ri> where $object <dc:identifier> '%s'"
    
    class << self
      
      def risearch(query)
        query_params = {
          :type => 'tuples',
          :lang => 'itql',
          :format => 'CSV',
          :limit => '1000',
          :query => query
        }
        
        client = RestClient::Resource.new(
          Dor::Config[:fedora_url],
          :ssl_client_cert  =>  OpenSSL::X509::Certificate.new(File.read(Dor::Config[:fedora_cert_file])),
          :ssl_client_key   =>  OpenSSL::PKey::RSA.new(File.read(Dor::Config[:fedora_key_file]), Dor::Config[:fedora_key_pass])
        )
        result = client['risearch'].post(query_params)
        result.split(/\n/)[1..-1].collect { |pid| pid.chomp.sub(/^info:fedora\//,'') }
      end
      
      def gsearch(params)
        client = RestClient::Resource.new(Dor::Config[:gsearch_solr_url])
        query_params = params.merge(:wt => 'json')
        query_string = query_params.collect { |k,v| "#{k}=#{URI.encode(v)}" }.join('&')
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