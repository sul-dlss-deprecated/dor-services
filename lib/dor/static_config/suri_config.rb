# frozen_string_literal: true

module Dor
  class StaticConfig
    # Represents the configuration for the identifier minter service (suri)
    class SuriConfig
      def initialize(hash)
        @mint_ids = hash.fetch(:mint_ids)
        @pass = hash.fetch(:pass)
        @id_namespace = hash.fetch(:id_namespace)
        @url = hash.fetch(:url)
        @user = hash.fetch(:user)
      end

      def configure(&block)
        instance_eval(&block)
      end

      def mint_ids(new_value = nil)
        @mint_ids = new_value if new_value
        @mint_ids
      end

      def id_namespace(new_value = nil)
        @id_namespace = new_value if new_value
        @id_namespace
      end

      def url(new_value = nil)
        @url = new_value if new_value
        @url
      end

      def user(new_value = nil)
        @user = new_value if new_value
        @user
      end

      def pass(new_value = nil)
        @pass = new_value if new_value
        @pass
      end
    end
  end
end
