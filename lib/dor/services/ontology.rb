# frozen_string_literal: true

module Dor
  class Ontology
    extend Deprecation
    self.deprecation_horizon = 'dor-services version 7.0.0'

    class << self
      def [](key)
        Deprecation.warn(self, "#{self}.[] is deprecated and will be removed in #{Dor::Ontology.deprecation_horizon}. Use `property' instead.")
        @data[key]
      end

      def key?(key)
        @data.key?(key)
      end

      def include?(key)
        Deprecation.warn(self, "#{self}.include? is deprecated and will be removed in #{Dor::Ontology.deprecation_horizon}. Use `key?' instead.")
        @data.include?(key)
      end

      def map(&block)
        Deprecation.warn(self, "#{self}.map is deprecated and will be removed in #{Dor::Ontology.deprecation_horizon}. Use `options' instead.")
        @data.map(&block)
      end

      # Yields each term to the block provided
      def options
        @data.map do |k, _v|
          yield property(k)
        end
      end

      def property(key)
        Term.new(@data[key].merge(key: key))
      end
    end

    class Term
      def initialize(uri:, human_readable:, key:, deprecation_warning: nil)
        @label = human_readable
        @uri = uri
        @deprecation_warning = deprecation_warning
        @key = key
      end

      attr_reader :label, :uri, :deprecation_warning, :key
    end
  end
end
