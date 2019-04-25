# frozen_string_literal: true

module Dor
  # Calls the purl service and returns the XML document
  class PurlClient
    def initialize(host:, pid:)
      @host = host
      @pid = pid
    end

    # Get XML from the purl service
    # Fetches purl xml for a druid
    # @raise [OpenURI::HTTPError]
    # @return [Nokogiri::HTML::Document] parsed XML for the druid or an empty document if no purl is found
    def fetch
      handler = proc do |exception, attempt_number, total_delay|
        # We assume a 404 means the document has never been published before and thus has no purl
        Dor.logger.warn "[Attempt #{attempt_number}] GET #{url} -- #{exception.class}: #{exception.message}; #{total_delay} seconds elapsed."
        raise exception unless exception.is_a? OpenURI::HTTPError
        return Nokogiri::HTML::Document.new if exception.io.status.first == '404' # ["404", "Not Found"] from OpenURI::Meta.status
      end

      with_retries(max_retries: 3, base_sleep_seconds: 3, max_sleep_seconds: 5, handler: handler) do |attempt|
        # If you change the method used for opening the webpage, you can change the :rescue param to handle the new method's errors
        Dor.logger.debug "[Attempt #{attempt}] GET #{url}"
        return Nokogiri::XML(OpenURI.open_uri(url))
      end
    end

    private

    # Take the and create the entire purl url that will usable for the open method in open-uri, returns http
    # @return [String] the full url
    def url
      @url ||= "https://#{@host}/#{druid_without_prefix}.xml"
    end

    def druid_without_prefix
      PidUtils.remove_druid_prefix(@pid)
    end
  end
end
