# frozen_string_literal: true

require 'json'
require 'active_support/core_ext'

module Dor
  # Used by Argo and dor-services-app
  class SearchService
    class << self
      def index_version
        Dor::VERSION
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

      private

      def solr
        ActiveFedora.solr.conn
      end
    end
  end
end
