# frozen_string_literal: true

# Creates RestClient::Resources for various connections
module Dor
  class RestResourceFactory
    include Singleton

    # @param url [String] the url to connect to
    # @return [RestClient::Resource]
    def self.create(url)
      instance.create(url)
    end

    # @param url [String] the url to connect to
    # @return [RestClient::Resource]
    def create(url)
      RestClient::Resource.new(url, connection_options)
    end

    private

    # @return [Hash] options for creating a RestClient::Resource
    def connection_options
      {}
    end
  end
end
