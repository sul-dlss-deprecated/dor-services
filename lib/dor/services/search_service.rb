require 'json'
require 'active_support/core_ext'

module Dor

  class SearchService

    include Solrizer::FieldNameMapper
    RISEARCH_TEMPLATE = "select $object from <#ri> where $object <dc:identifier> '%s'"
    @@index_version = nil

    class << self

      def index_version
        if @@index_version.nil?
          xsl_doc = Nokogiri::XML(File.read(File.expand_path('../../../gsearch/demoFoxmlToSolr.xslt',__FILE__)))
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

      def iterate_over_pids(opts = {}, &block)
        opts[:query] ||= "select $object from <#ri> where $object <info:fedora/fedora-system:def/model#label> $label"
        opts[:in_groups_of] ||= 100
        opts[:mode] ||= :single
        start = 0
        pids = Dor::SearchService.risearch("#{opts[:query]} limit #{opts[:in_groups_of]} offset #{start}")
        while pids.present?
          if opts[:mode] == :single
            pids.each { |pid| yield pid }
          else
            yield pids
          end
          start += pids.length
          pids = Dor::SearchService.risearch("#{opts[:query]} limit #{opts[:in_groups_of]} offset #{start}")
        end
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
        result = JSON.parse(client["select?#{query_string}"].get)
      end

      def query query, args = {}
        params = args.merge({ :q => query })
        params[:start] ||= 0
        resp = solr.find params
        if block_given?
          cont = true
          while cont and resp.docs.length > 0
            cont = yield(resp)
            params[:rows] ||= resp.docs.length
            params[:start] += params[:rows]
            resp = solr.find params
          end
        else
          return resp
        end
      end

      def query_by_id(id)
        if id.is_a?(Hash) # Single valued: { :google => 'STANFORD_0123456789' }
          id = id.collect { |*v| v.join(':') }.first
        elsif id.is_a?(Array) # Two values: [ 'google', 'STANFORD_0123456789' ]
          id = id.join(':')
        end
        q = %{#{solr_name 'identifier', :string}:"#{id}"}
        result = []
        resp = query(q, :fl => 'id', :rows => 1000) do |resp|
          result += resp.docs.collect { |doc| doc['id'] }
          true
        end
        result
      end

      def solr
        @@solr ||= ActiveFedora.solr.conn.is_a?(RSolr::Client) ? ActiveFedora.solr.conn : Dor::Config.make_solr_connection
      end

      # @return String druid of the SDR Graveyard APO
      #   nil if APO does not exist in the currently configured environment
      def sdr_graveyard_apo_druid
        @@sdr_graveyard_apo ||= find_sdr_graveyard_apo_druid
      end

      def find_sdr_graveyard_apo_druid
        r = Dor::SearchService.query('dc_title_t:"SDR Graveyard"', :fl => 'id')
        if r.docs.empty?
          nil
        else
          r.docs.first[:id]
        end
      end

    end

  end

end
