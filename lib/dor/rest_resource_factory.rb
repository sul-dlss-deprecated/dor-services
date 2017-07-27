# Creates RestClient::Resources for various connections
module Dor
  class RestResourceFactory
    include Singleton

    # @param type [Symbol] the type of connection to create (e.g. :fedora)
    # @return [RestClient::Resource]
    def self.create(type)
      instance.create(type)
    end

    # @param type [Symbol] the type of connection to create (e.g. :fedora)
    # @return [RestClient::Resource]
    def create(type)
      RestClient::Resource.new(url_for(type), connection_options)
    end

    private

    # @param type [Symbol] the type of connection to create (e.g. :fedora)
    # @return [String] the url to connect to.
    def url_for(type)
      connection_configuration(type).url
    end

    # @param type [Symbol] the type of connection to create (e.g. :fedora)
    # @return [#url] the configuration for the connection
    def connection_configuration(type)
      Dor::Config.fetch(type)
    rescue KeyError
      raise "ERROR: Unable to find a configuration for #{type}"
    end

    # @return [Hash] options for creating a RestClient::Resource
    def connection_options
      {}
    end
  end
end
