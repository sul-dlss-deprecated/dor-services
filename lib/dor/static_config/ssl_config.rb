# frozen_string_literal: true

module Dor
  class StaticConfig
    class SslConfig
      # Represents the client side certificate configuration for Fedora 3
      def initialize(hash)
        @cert_file = hash.fetch(:cert_file)
        @key_file = hash.fetch(:key_file)
        @key_pass = hash.fetch(:key_pass)
      end

      def configure(&block)
        instance_eval(&block)
      end

      def cert_file(new_value = nil)
        @cert_file = new_value if new_value
        @cert_file
      end

      def key_file(new_value = nil)
        @key_file = new_value if new_value
        @key_file
      end

      def key_pass(new_value = nil)
        @key_pass = new_value if new_value
        @key_pass
      end
    end
  end
end
