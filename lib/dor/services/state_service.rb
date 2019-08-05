# frozen_string_literal: true

module Dor
  class StateService
    def initialize(pid)
      @pid = pid
    end

    def allows_modification?
      !client.lifecycle('dor', pid, 'submitted') ||
        client.active_lifecycle('dor', pid, 'opened') ||
        client.workflow_status('dor', pid, 'accessionWF', 'sdr-ingest-transfer') == 'hold'
    end

    private

    attr_reader :pid

    def client
      Dor::Config.workflow.client
    end
  end
end
