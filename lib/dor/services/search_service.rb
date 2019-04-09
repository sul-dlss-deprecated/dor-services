# frozen_string_literal: true

require 'json'
require 'active_support/core_ext'

module Dor
  class SearchService
    extend Deprecation
    RISEARCH_TEMPLATE = "select $object from <#ri> where $object <dc:identifier> '%s'"
    @@index_version = nil

    class << self
      def index_version
        Dor::VERSION
      end

      # @deprecated because this depends on Fedora 3 having sparql turned on
      def risearch(query, opts = {})
        Deprecation.warn(self, 'risearch is deprecated and will be removed in dor-services 7')
        client = Config.fedora.client['risearch']
        client.options[:timeout] = opts.delete(:timeout)
        query_params = {
          type: 'tuples',
          lang: 'itql',
          format: 'CSV',
          limit: '1000',
          stream: 'on',
          query: query
        }.merge(opts)
        result = client.post(query_params)
        result.split(/\n/)[1..-1].collect { |pid| pid.chomp.sub(/^info:fedora\//, '') }
      end

      # @deprecated because this depends on Fedora 3 having sparql turned on
      def iterate_over_pids(opts = {})
        Deprecation.warn(self, 'iterate_over_pids is deprecated and will be removed in dor-services 7')
        opts[:query] ||= 'select $object from <#ri> where $object <info:fedora/fedora-system:def/model#label> $label'
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

      def query(query, args = {})
        params = args.merge(q: query)
        params[:start] ||= 0
        resp = solr.get 'select', params: params
        return resp unless block_given?

        cont = true
        while cont && resp['response']['docs'].length > 0
          cont = yield(resp)
          params[:rows] ||= resp['response']['docs'].length
          params[:start] += params[:rows]
          resp = solr.get 'select', params: params
        end
      end

      def query_by_id(id)
        if id.is_a?(Hash) # Single valued: { :google => 'STANFORD_0123456789' }
          id = id.collect { |*v| v.join(':') }.first
        elsif id.is_a?(Array) # Two values: [ 'google', 'STANFORD_0123456789' ]
          id = id.join(':')
        end
        q = "{!term f=#{Solrizer.solr_name 'identifier', :symbol}}#{id}"
        result = []
        query(q, fl: 'id', rows: 1000, defType: 'lucene') do |resp|
          result += resp['response']['docs'].collect { |doc| doc['id'] }
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
        r = Dor::SearchService.query('dc_title_tesim:"SDR Graveyard"', fl: 'id')
        if r['response']['docs'].empty?
          nil
        else
          r['response']['docs'].first[:id]
        end
      end
    end
  end
end
