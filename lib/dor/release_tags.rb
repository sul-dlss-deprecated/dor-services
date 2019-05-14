# frozen_string_literal: true

module Dor
  module ReleaseTags
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :PurlClient
      autoload :Purl
      autoload :IdentityMetadata
    end
  end
end
