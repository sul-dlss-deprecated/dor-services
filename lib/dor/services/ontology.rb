# frozen_string_literal: true

module Dor
  class Ontology
    extend Deprecation
    self.deprecation_horizon = 'dor-services version 7.0.0'

    def self.[](key)
      @data[key]
    end
    deprecation_deprecate :[] => 'Use property() instead'

    def self.key?(key)
      @data.key?(key)
    end

    def self.include?(key)
      @data.include?(key)
    end
    deprecation_deprecate include?: 'Use key? instead'

    def self.property(key)
      Term.new(@data[key])
    end

    class Term
      def initialize(uri:, human_readable:)
        @label = human_readable
        @uri = uri
      end

      attr_reader :label, :uri
    end
  end
end
