require 'json'
require 'active_support/core_ext'

module Dor
  
  class SearchService

    RISEARCH_TEMPLATE = "select $object from <#ri> where $object <dc:identifier> '%s'"

    Config.declare(:gsearch) { url nil }
    
    class << self
      
      def reindex(*pids)
        fedora_client = RestClient::Resource.new(
          Config.fedora.url,
          :ssl_client_cert  =>  OpenSSL::X509::Certificate.new(File.read(Config.fedora.cert_file)),
          :ssl_client_key   =>  OpenSSL::PKey::RSA.new(File.read(Config.fedora.key_file), Config.fedora.key_pass)
        )
        solr_client = RestClient::Resource.new(
          Config.gsearch.url,
          :ssl_client_cert  =>  OpenSSL::X509::Certificate.new(File.read(Config.fedora.cert_file)),
          :ssl_client_key   =>  OpenSSL::PKey::RSA.new(File.read(Config.fedora.key_file), Config.fedora.key_pass)
        )
        xsl = Nokogiri::XSLT(File.read(File.expand_path('../../gsearch/demoFoxmlToSolr.xslt', __FILE__)))
        pids.in_groups_of(20, false) do |group|
          doc = Nokogiri::XML('<update/>')
          group.each do |pid|
            begin
              foxml = Nokogiri::XML(fedora_client["objects/#{pid}/objectXML"].get)
              doc.root.add_child(xsl.transform(foxml).root)
            rescue RestClient::ResourceNotFound
              doc.root.add_child("<delete><id>#{pid}</id></delete>")
            end
          end
          yield group if block_given?
          solr_client['update'].post(doc.to_xml, :content_type => 'application/xml')
        end
        pids
      end

      def risearch(query)
        query_params = {
          :type => 'tuples',
          :lang => 'itql',
          :format => 'CSV',
          :limit => '1000',
          :query => query
        }
        
        client = RestClient::Resource.new(
          Config.fedora.url,
          :ssl_client_cert  =>  OpenSSL::X509::Certificate.new(File.read(Config.fedora.cert_file)),
          :ssl_client_key   =>  OpenSSL::PKey::RSA.new(File.read(Config.fedora.key_file), Config.fedora.key_pass)
        )
        result = client['risearch'].post(query_params)
        result.split(/\n/)[1..-1].collect { |pid| pid.chomp.sub(/^info:fedora\//,'') }
      end
      
      def gsearch(params)
        client = RestClient::Resource.new(
          Config.gsearch.url,
          :ssl_client_cert  =>  OpenSSL::X509::Certificate.new(File.read(Config.fedora.cert_file)),
          :ssl_client_key   =>  OpenSSL::PKey::RSA.new(File.read(Config.fedora.key_file), Config.fedora.key_pass)
        )
        query_params = params.merge(:wt => 'json')
        query_string = query_params.collect { |k,v| 
          if v.is_a?(Array)
            v.collect { |vv| "#{k}=#{URI.encode(vv.to_s)}" }.join('&')
          else
            "#{k}=#{URI.encode(v.to_s)}" 
          end
        }.join('&')
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