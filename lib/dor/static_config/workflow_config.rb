# frozen_string_literal: true

module Dor
  class StaticConfig
    # Represents the configuration for the workflow service
    class WorkflowConfig
      def initialize(hash)
        @url = hash.fetch(:url)
        @timeout = hash.fetch(:timeout)
        @logfile = hash.fetch(:logfile)
        @shift_age = hash.fetch(:shift_age)
      end

      def configure(&block)
        instance_eval(&block)
      end

      def client
        @client ||= Dor::Workflow::Client.new(url: url, logger: client_logger, timeout: timeout)
      end

      def url(new_value = nil)
        @url = new_value if new_value
        @url
      end

      def timeout(new_value = nil)
        @timeout = new_value if new_value
        @timeout
      end

      def logfile(new_value = nil)
        @logfile = new_value if new_value
        @logfile
      end

      def shift_age(new_value = nil)
        @shift_age = new_value if new_value
        @shift_age
      end

      def client_logger
        if logfile && shift_age
          Logger.new(logfile, shift_age)
        elsif logfile
          Logger.new(logfile)
        end
      end
    end
  end
end
